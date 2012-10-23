exports = window.chat ?= {}

class Chat extends EventEmitter

  constructor: ->
    super
    @connections = {}
    @messageHandler = new chat.IRCMessageHandler this

    @userCommands = new chat.UserCommandHandler this
    devCommands = new chat.DeveloperCommands this
    @userCommands.merge devCommands

    @_initializeUI()
    @_initializeRemoteConnection()
    @_initializeSyncStorage()

    document.title = "CIRC #{irc.VERSION}"

  _initializeUI: ->
    @winList = new chat.WindowList
    @channelDisplay = new chat.ChannelList()
    @channelDisplay.on 'clicked', (server, chan) =>
      win = @winList.get server, chan
      @switchToWindow win if win?
    @_addWelcomeWindow()

  _addWelcomeWindow: ->
    @emptyWindow = new chat.Window 'none'
    @channelDisplay.addServer @emptyWindow.name
    @switchToWindow @emptyWindow
    @emptyWindow.messageRenderer.displayWelcome()

  _initializeRemoteConnection: ->
    @remoteConnection = new RemoteConnection
    @userCommands.listenTo @remoteConnection
    @remoteConnection.setAuthTokenGenerator @_generateAuthenticationToken
    @remoteConnection.on 'irc_state', (state) =>
      @closeAllConnections()
      @syncStorage.loadState this, state

  _generateAuthenticationToken: (value) =>
    hex_md5 @password + value

  _initializeSyncStorage: ->
    @syncStorage = new chat.SyncStorage
    @remoteConnection.setStateGenerator =>
      @syncStorage.getState this
    @syncStorage.restoreSavedState this

  ##
  # Loads servers, channels and nick from the given IRC state.
  # The state has the following format:
  # { nicks: Array.<{server, name}>, channels: Array.<{sevrer, name}>,
  #     servers: Array.<{name, port}> }
  # @param {Object} state An object that represents the current state of an IRC
  #     client.
  ##
  closeAllConnections: ->
     for server, conn of @connections
      @closeConnection conn

  closeConnection: (conn) ->
    if conn.irc.state is 'reconnecting'
      conn.irc.giveup()
    else
      conn.irc.quit @reason
    @removeWindow @winList.get conn.name

  listenToCommands: (userInput) ->
    @remoteConnection.broadcastUserInput userInput
    @userCommands.listenTo userInput
    userInput.on 'switch_window', (winNum) =>
      @switchToWindowByIndex winNum

  listenToScriptEvents: (@scriptHandler) ->
    # TODO - allow scripts to create notifications and plain text
    #scriptHandler.on 'notify', @createNotification
    #scriptHandler.on 'print', @printText

  listenToIRCEvents: (@ircEvents) ->
    @ircEvents.on 'server', @onIRCEvent
    @ircEvents.on 'message', @onIRCEvent

  connect: (server, port) ->
    if server of @connections
      # TODO disconnect and reconnect if port changed
      return if @connections[server].irc.state in ['connected', 'connecting']
    else
      @_createConnection server
      @_createWindowForServer server, port
    @connections[server].irc.connect(server, port)

  _createConnection: (server) ->
    irc = new window.irc.IRC
    irc.setSocket @remoteConnection.createSocket server
    irc.setPreferredNick @previousNick if @previousNick
    @ircEvents?.addEventsFrom irc
    @connections[server] = {irc:irc, name: server, windows:{}}

  _createWindowForServer: (server, port) ->
    conn = @connections[server]
    win = new chat.Window conn.name
    @_replaceEmptyWindowIfExists win
    win.message '', "Connecting to #{conn.name}..."
    win.conn = conn
    conn.serverWindow = win
    @winList.add win
    @channelDisplay.addServer conn.name
    @syncStorage.serverJoined conn.name, port
    @switchToWindow win

  _replaceEmptyWindowIfExists: (win) ->
    if @currentWindow.equals @emptyWindow
      @channelDisplay.remove @emptyWindow.name
      win.messageRenderer.displayWelcome()

  join: (conn, channel) ->
    win = @_createWindowForChannel conn, channel
    @switchToWindow win
    conn.irc.join channel

  setNick: (opt_server, nick) ->
    unless nick
      nick = opt_server
      server = undefined
    else
      server = opt_server
    conn = @connections[server]
    @previousNick = nick
    @syncStorage.nickChanged nick
    @updateStatus()
    conn?.irc.doCommand 'NICK', nick
    conn?.irc.setPreferredNick nick

  onIRCEvent: (e) =>
    conn = @connections[e.context.server]
    if e.type is 'server' then @onServerEvent conn, e
    else @onMessageEvent conn, e

  onServerEvent: (conn, e) =>
    return if not conn
    switch e.name
      when 'connect' then @onConnected conn
      when 'disconnect' then @onDisconnected conn
      when 'joined' then @onJoined conn, e.context.channel, e.args...
      when 'names' then @onNames e, e.args...
      when 'parted' then @onParted e

  onMessageEvent: (conn, e) =>
    win = @determineWindow e
    return if win is chat.NO_WINDOW
    @messageHandler.setWindow(win)
    @messageHandler.setCustomMessageStyle(e.style)
    @messageHandler.handle e.name, e.args...

  determineWindow: (e) ->
    conn = @connections[e.context.server]
    return @emptyWindow unless conn
    if e.context.channel is chat.CURRENT_WINDOW and
        e.context.server isnt @currentWindow.conn?.name
      e.context.channel = chat.SERVER_WINDOW
    chan = e.context.channel
    if conn?.irc.isOwnNick chan
      return chat.NO_WINDOW unless e.name is 'privmsg'
      from = e.args[0]
      conn.windows[from] ?= @_createWindowForChannel conn, from
      conn.windows[from].makePrivate()
      @channelDisplay.connect conn.name, from
      return conn.windows[from]
    if not chan or chan is chat.SERVER_WINDOW
      return conn.serverWindow
    if chan is chat.CURRENT_WINDOW
      return @currentWindow
    if conn.windows[chan]
      return conn.windows[chan]
    return chat.NO_WINDOW

  onConnected: (conn) ->
    @displayMessage 'connect', {server: conn.name}
    @updateStatus()
    @channelDisplay.connect conn.name
    for chan, win of conn.windows
      @displayMessage 'connect', {server: conn.name, channel: win.target}
      @channelDisplay.connect conn.name, chan if win.isPrivate()

  onDisconnected: (conn) ->
    @displayMessage 'disconnect', {server: conn.name}
    @channelDisplay.disconnect conn.name
    for chan, win of conn.windows
      @channelDisplay.disconnect conn.name, chan
      @displayMessage 'disconnect', {server: conn.name, channel: win.target}

  onJoined: (conn, chan) ->
    win = @_createWindowForChannel conn, chan
    @channelDisplay.connect conn.name, chan
    win.nicks.clear()

  _createWindowForChannel: (conn, chan) ->
    win = conn.windows[chan]
    if not win
      win = @makeWin conn, chan
      i = @winList.localIndexOf win
      @channelDisplay.insertChannel i, conn.name, chan
      @syncStorage.channelJoined conn.name, chan
    win

  onNames: (e, nicks) ->
    win = @determineWindow e
    return if win is chat.NO_WINDOW
    for nick in nicks
      win.nicks.add nick

  onParted: (e) ->
    win = @determineWindow e
    return if win is chat.NO_WINDOW
    @channelDisplay.disconnect win.conn.name, win.target

  removeWindow: (win=@currentWindow) ->
    index = @winList.indexOf win
    if win.isServerWindow()
      @ircEvents.removeEventsFrom win.conn.irc
    removedWindows = @winList.remove win
    for win in removedWindows
      @_removeWindowFromState win
    @_selectNextWindow(index)

  _removeWindowFromState: (win) ->
    @channelDisplay.remove win.conn.name, win.target
    @syncStorage.parted win.conn.name, win.target
    if win.target?
      delete @connections[win.conn.name].windows[win.target]
    else
      delete @connections[win.conn.name]
    win.remove()

  _selectNextWindow: (preferredIndex) ->
    if @winList.length is 0
      @channelDisplay.addServer @emptyWindow.name
      @switchToWindow @emptyWindow
    else if @winList.indexOf(@currentWindow) == -1
      nextWin = @winList.get(preferredIndex) ? @winList.get(preferredIndex - 1)
      @switchToWindow nextWin
    else
      @switchToWindow @currentWindow

  makeWin: (conn, chan) ->
    throw new Error("we already have a window for that") if conn.windows[chan]
    win = conn.windows[chan] = new chat.Window(conn.name, chan)
    win.conn = conn
    win.setTarget chan
    @winList.add win
    win

  updateStatus: ->
    statusList = []
    nick = @currentWindow.conn?.irc.nick ? @previousNick
    away = @currentWindow.conn?.irc.away
    channel = @currentWindow.target
    topic = @currentWindow.conn?.irc.channels[channel]?.topic
    statusList.push "<span class='nick'>#{nick}</span>" if nick
    statusList.push "<span class='away'>away</span>" if away
    statusList.push "<span class='topic'>#{topic}</span>" if topic
    $('#status').html(statusList.join '') if statusList.length > 0

  switchToWindowByIndex: (winNum) ->
    winNum = 10 if winNum is 0
    win = @winList.get winNum - 1
    @switchToWindow win if win?

  switchToWindow: (win) ->
    throw new Error("switching to non-existant window") if not win?
    @currentWindow.detach() if @currentWindow
    @currentWindow = win
    win.attach()
    @_selectWindowInChannelDisplay win
    @updateStatus()

  _selectWindowInChannelDisplay: (win) ->
    if win.conn
      @channelDisplay.select win.conn.name, win.target
    else
      @channelDisplay.select win.name

  # emits message to script handler, which decides if it should send it back
  displayMessage: (name, context, args...) ->
    event = new Event 'message', name, args...
    event.setContext context.server, context.channel
    @emit event.type, event

exports.SERVER_WINDOW = '@server_window'
exports.CURRENT_WINDOW = '@current_window'
exports.NO_WINDOW = 'NO_WINDOW'

exports.Chat = Chat