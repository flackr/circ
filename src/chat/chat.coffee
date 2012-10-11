exports = window.chat ?= {}

class Chat extends EventEmitter

  constructor: ->
    super
    @messageHandler = new chat.IRCMessageHandler this
    @userCommands = new chat.UserCommandHandler this
    devCommands = new chat.DeveloperCommands @userCommands
    @userCommands.merge devCommands

    @winList = new chat.WindowList
    @channelDisplay = new chat.ChannelList()
    @channelDisplay.on 'clicked', (server, chan) =>
      win = @winList.get server, chan
      @switchToWindow win if win?

    @$windowContainer = $('#chat')
    @emptyWindow = new chat.Window 'none'
    @channelDisplay.add @emptyWindow.name
    @switchToWindow @emptyWindow
    @connections = {}

    @currentWindow.message '', "Welcome to CIRC, a packaged Chrome app.", "system"
    @currentWindow.emptyLine()
    @currentWindow.message '', "Visit https://github.com/noahsug/circ/wiki to read documentation or report an issue.", "system"
    @currentWindow.emptyLine()
    @currentWindow.message '', "Type /server <server> [port] to connect, then /nick <my_nick> and /join <#channel>.", "system"
    @currentWindow.emptyLine()
    @currentWindow.message '', "Type /help to see a full list of commands.", "system"
    @currentWindow.emptyLine()
    @currentWindow.message '', "Switch windows with alt+[0-9] or clicking in the channel list on the left.", "system"

    document.title = "CIRC #{irc.VERSION}"
    @syncStorage = new chat.SyncStorage
    @syncStorage.restoreState this

  listenToCommands: (commandInput) ->
    @userCommands.listenTo commandInput
    commandInput.on 'switch_window', (winNum) =>
      @switchToWindowByIndex winNum

  listenToScriptEvents: (@scriptHandler) ->
    # TODO - allow scripts to create notifications and plain text
    #scriptHandler.on 'notify', @createNotification
    #scriptHandler.on 'print', @printText

  listenToIRCEvents: (@ircEvents) ->
    @ircEvents.on 'server', @onIRCEvent
    @ircEvents.on 'message', @onIRCEvent

  connect: (server, port) ->
    if irc = @connections[server]?.irc
      return if irc.state in ['connected', 'connecting']
    else
      win = new chat.Window server
      win.message '*', "Connecting to #{server}..."
      irc = new window.irc.IRC
      conn = @connections[server] = {irc:irc, name: server, serverWindow:win, windows:{}}
      win.conn = conn
      @winList.add win
      @ircEvents?.addEventsFrom irc
      @channelDisplay.add conn.name
      irc.setPreferredNick @previousNick if @previousNick?
      if @currentWindow.equals @emptyWindow
        @channelDisplay.remove @emptyWindow.name
        @switchToWindow win
    irc.connect(server, port)

  join: (conn, channel) ->
    win = @_createWindowForChannel conn, channel
    @switchToWindow win
    conn.irc.join channel

  onIRCEvent: (e) =>
    if e.context.channel is chat.CURRENT_WINDOW and
        e.context.server isnt @currentWindow.conn?.name
      e.context.channel = chat.SERVER_WINDOW
    conn = @connections[e.context.server]
    return if not conn
    if e.type is 'server' then @onServerEvent conn, e
    else @onMessageEvent conn, e

  onServerEvent: (conn, e) =>
    switch e.name
      when 'connect' then @onConnected conn
      when 'disconnect' then @onDisconnected conn
      when 'joined' then @onJoined conn, e.context.channel, e.args...
      when 'names' then @onNames conn, e.context.channel, e.args...
      when 'parted' then @onParted conn, e.context.channel, e.args...

  onMessageEvent: (conn, e) =>
    win = @_determineWindow conn, e
    return if win is chat.NO_WINDOW
    @messageHandler.setWindow(win)
    @messageHandler.setCustomMessageStyle(e.style)
    @messageHandler.handle e.name, e.args...

  _determineWindow: (conn, e) ->
    chan = e.context.channel
    if conn.irc.isOwnNick chan
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
      i = @winList.indexOf win
      @channelDisplay.insert i, conn.name, chan
    win

  onNames: (conn, chan, nicks) ->
    return unless win = conn.windows[chan]
    for nick in nicks
      win.nicks.add nick

  onParted: (conn, chan) ->
    if win = conn.windows[chan]
      @channelDisplay.disconnect conn.name, chan

  removeWindow: (win=@currentWindow) ->
    index = @winList.indexOf win
    removedWindows = @winList.remove win
    for win in removedWindows
      @_removeWindowFromState win
    @_selectNextWindow(index)

  _removeWindowFromState: (win) ->
    @channelDisplay.remove win.conn.name, win.target
    if win.target?
      delete @connections[win.conn.name].windows[win.target]
    else
      delete @connections[win.conn.name]
    win.remove()

  _selectNextWindow: (preferredIndex) ->
    if @winList.length is 0
      @channelDisplay.add @emptyWindow.name
      @switchToWindow @emptyWindow
    else if @winList.indexOf(@currentWindow) == -1
      nextWin = @winList.get(preferredIndex) ? @winList.get(preferredIndex - 1)
      @switchToWindow nextWin

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
    statusList.push "[#{nick}]" if nick
    statusList.push "(away)" if away
    statusList.push "#{channel}" if channel
    statusList.push "- #{topic}" if topic
    statusList.push 'Welcome!' if statusList.length is 0
    $('#status').text(statusList.join ' ')

  switchToWindowByIndex: (winNum) ->
      winNum = 10 if winNum is 0
      win = @winList.get winNum - 1
      @switchToWindow win if win?

  switchToWindow: (win) ->
    throw new Error("switching to non-existant window") if not win?
    @currentWindow.detach() if @currentWindow
    win.attachTo @$windowContainer
    @currentWindow = win
    if win.conn?
      @channelDisplay.select win.conn.name, win.target
    else
      @channelDisplay.select Chat.NoConnName
    @updateStatus()

  # emits message to script handler, which decides if it should send it back
  displayMessage: (name, context, args...) ->
    event = new Event 'message', name, args...
    event.setContext context.server, context.channel
    @emit event.type, event

exports.SERVER_WINDOW = '@server_window'
exports.CURRENT_WINDOW = '@current_window'
exports.NO_WINDOW = 'NO_WINDOW'

exports.Chat = Chat