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
    @_initializeStorage()
    @_initializeScripts()
    @_listenForUpdates()

    @updateStatus()

  init: ->
    if api.socketSupported()
      @storage.init()
      @remoteConnection.init()
    else
      @_displaySocketSupportError()

  ##
  # Tell the user that they need chrome.socket support to run CIRC.
  ##
  _displaySocketSupportError: ->
    message = "CIRC cannot run on this device. Support for " +
        "chrome.socket is required to connect to the IRC server. " +
        "Please update your version of Chrome and try again."
    @displayMessage 'error', @getCurrentContext(), message

  tearDown: ->
    @emit 'tear_down'

  _initializeUI: ->
    @winList = new chat.WindowList
    @notice = new chat.Notice
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
    @remoteConnectionHandler = new chat.RemoteConnectionHandler this
    @remoteConnectionHandler.setRemoteConnection @remoteConnection

  _initializeStorage: ->
    @storage = new chat.Storage this
    @remoteConnectionHandler.setStorageHandler @storage

  ##
  # Load prepackaged scripts the first time the app is run. These scripts are
  # loaded from storage on subsequent runs.
  ##
  _initializeScripts: ->
    @storage.on 'initialized', =>
      return if @storage.loadedPrepackagedScripts
      window.script.loader.loadPrepackagedScripts (script) =>
        @addScript script
      @storage.finishedLoadingPrepackagedScripts()

  ##
  # Inform listeners (like ScriptHandler) that a script has been loaded and
  # save the script to local storage.
  # @param {Script} script
  ##
  addScript: (script) ->
    @scriptHandler.addScript script
    @storage.scriptAdded script

  _listenForUpdates: ->
    return unless chrome.runtime.reload?
    chrome.runtime.onUpdateAvailable?.addListener =>
      @_promptToUpdate()

  _promptToUpdate: ->
    message = "A new versionn of CIRC is available. Would you like to " +
        "restart and update? [update]"
    @notice.prompt message, =>
      chrome.runtime.reload()

  startWalkthrough: ->
    walkthrough = new chat.Walkthrough this, @storage
    walkthrough.listenToIRCEvents @_ircEvents
    walkthrough.on 'tear_down', =>
      @storage.finishedWalkthrough()

  setPassword: (password) ->
    @remoteConnection.setPassword password

  closeAllConnections: ->
    clearTimeout @_useOwnConnectionTimeout
    for server, conn of @connections
      @closeConnection conn

  closeConnection: (conn) ->
    if conn.irc.state is 'reconnecting'
      conn.irc.giveup()
    else
      conn.irc.quit @reason
    @removeWindow @winList.get conn.name

  listenToCommands: (commandEmitter) ->
    @remoteConnection.broadcastUserInput commandEmitter
    @userCommands.listenTo commandEmitter

  listenToScriptEvents: (@scriptHandler) ->
    # TODO - allow scripts to create notifications and plain text
    #scriptHandler.on 'notify', @createNotification
    #scriptHandler.on 'print', @printText

  listenToIRCEvents: (ircEvents) ->
    @_ircEvents = ircEvents
    @_ircEvents.on 'server', @onIRCEvent
    @_ircEvents.on 'message', @onIRCEvent

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
    irc.setPreferredNick @preferredNick if @preferredNick
    @_ircEvents?.addEventsFrom irc
    @connections[server] = {irc:irc, name: server, windows:{}}

  _createWindowForServer: (server, port) ->
    conn = @connections[server]
    win = @_makeWin conn
    @_replaceEmptyWindowIfExists win
    win.message '', "Connecting to #{conn.name}..."
    @channelDisplay.addServer conn.name
    @storage.serverJoined conn.name, port
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
    @_setNickLocally nick
    @_tellServerNickChanged nick, server
    @_emitNickChangedEvent nick

  _setNickLocally: (nick) ->
    @preferredNick = nick
    @storage.nickChanged nick
    @updateStatus()

  _tellServerNickChanged: (nick, server) ->
    conn = @connections[server]
    conn?.irc.doCommand 'NICK', nick
    conn?.irc.setPreferredNick nick

  _emitNickChangedEvent: (nick) ->
    event = new Event 'server', 'nick', nick
    event.setContext @getCurrentContext()
    @emit event.type, event

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
      when 'nick' then @updateStatus()

  onMessageEvent: (conn, e) =>
    win = @determineWindow e
    return if win is chat.NO_WINDOW
    @messageHandler.setWindow(win)
    @messageHandler.setCustomMessageStyle(e.style)
    @messageHandler.handle e.name, e.args...

  ##
  # Determine the window for which the event belongs.
  # @param {Event} e The event whose context we're looking at.
  ##
  determineWindow: (e) ->
    conn = @connections[e.context.server]
    return @emptyWindow unless conn
    if e.context.channel is chat.CURRENT_WINDOW and
        e.context.server isnt @currentWindow.conn?.name
      e.context.channel = chat.SERVER_WINDOW

    chan = e.context.channel
    if @_isDirectMessageToUser(conn, chan, e.name)
      from = e.args?[0]
      unless conn.windows[from]
        @createPrivateMessageWindow conn, from
      return conn.windows[from]

    if not chan or chan is chat.SERVER_WINDOW
      return conn.serverWindow
    if chan is chat.CURRENT_WINDOW
      return @currentWindow
    if conn.windows[chan]
      return conn.windows[chan]
    return chat.NO_WINDOW

  ##
  # Direct messages (e.g. /msg) have the channel set to the user's nick.
  ##
  _isDirectMessageToUser: (conn, chan, type) ->
    conn?.irc.isOwnNick(chan) and type is 'privmsg'

  createPrivateMessageWindow: (conn, from) ->
    return conn.windows[from] if conn.windows[from]
    @storage.channelJoined conn.name, from, 'private'
    win = conn.windows[from] = @_createWindowForChannel conn, from
    win.makePrivate()
    win.message '', "You're in a private conversation with #{from}.", 'notice'
    @channelDisplay.connect conn.name, from
    win

  ##
  # Keep track of the last person to mention the user's nick in each room.
  ##
  recordLastUserToMention: (context, user) ->
    @_lastUsersToMention ?= {}
    @_lastUsersToMention[context] = user

  ##
  # Returns the last person to mention the user's nick for a given room.
  ##
  getLastUserToMention: (context) ->
    @_lastUsersToMention?[context]

  onConnected: (conn) ->
    @displayMessage 'connect', {server: conn.name}
    @updateStatus()
    @channelDisplay.connect conn.name
    for chan, win of conn.windows when not win.isPrivate()
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
      win = @_makeWin conn, chan
      i = @winList.localIndexOf win
      @channelDisplay.insertChannel i, conn.name, chan
      @storage.channelJoined conn.name, chan
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
      @_ircEvents?.removeEventsFrom win.conn.irc
    removedWindows = @winList.remove win
    for win in removedWindows
      @_removeWindowFromState win
    @_selectNextWindow(index)

  _removeWindowFromState: (win) ->
    @channelDisplay.remove win.conn.name, win.target
    @storage.parted win.conn.name, win.target
    win.notifications.clear()
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

  _makeWin: (conn, opt_chan) ->
    win = new chat.Window conn.name, opt_chan
    win.conn = conn
    if opt_chan
      conn.windows[opt_chan] = win
      win.setTarget opt_chan
    else
      conn.serverWindow = win
    @winList.add win
    @messageHandler.logMessagesFromWindow win
    win

  updateStatus: ->
    statusList = []
    nick = @currentWindow.conn?.irc.nick ? @preferredNick
    away = @currentWindow.conn?.irc.away
    channel = @currentWindow.target
    topic = @currentWindow.conn?.irc.channels[channel]?.topic
    statusList.push "<span class='nick'>#{html.escape nick}</span>" if nick
    statusList.push "<span class='away'>away</span>" if away
    statusList.push "<span class='topic'>#{html.display topic}</span>" if topic
    $('#status').html(statusList.join '')
    @_updateDocumentTitle()

  _updateDocumentTitle: ->
    titleList = []
    titleList.push "CIRC #{irc.VERSION}"
    if @remoteConnection?.isClient()
      titleList.push '- Connected through ' +
          @remoteConnection.serverDevice.addr
    else if @remoteConnection?.isServer()
      connectedDevices = @remoteConnection.devices.length
      titleList.push "- Server for #{connectedDevices} " +
          "other #{pluralize 'device', connectedDevices}"

    document.title = titleList.join ' '

  ##
  # Switch to a window that represents a channel by its position in the rooms
  # list.
  ##
  switchToChannelByIndex: (winNum) ->
    win = @winList.getChannelWindow winNum
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

  displayMessage: (name, context, args...) ->
    event = new Event 'message', name, args...
    event.setContext context.server, context.channel
    @emit event.type, event

  getCurrentContext: ->
    new Context @currentWindow.conn?.name, chat.CURRENT_WINDOW

exports.SERVER_WINDOW = '@server_window'
exports.CURRENT_WINDOW = '@current_window'
exports.NO_WINDOW = 'NO_WINDOW'

exports.Chat = Chat