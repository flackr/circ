exports = window.chat ?= {}

class Chat extends EventEmitter

  constructor: ->
    super
    @$windowContainer = $('#chat')
    @context = new chat.ClientState this
    @context.channelDisplay = new chat.ChannelList()
    @context.channelDisplay.on 'clicked', (server, chan) =>
      win = @context.winList.get server, chan
      @switchToWindow win if win?

    @context.emptyWindow = new chat.Window 'none'
    @context.channelDisplay.add @context.emptyWindow.name
    @switchToWindow @context.emptyWindow
    @context.winList = new chat.WindowList()
    @context.connections = {}

    @context.currentWindow.message '', "Welcome to CIRC, a packaged Chrome app.", "system"
    @context.currentWindow.emptyLine()
    @context.currentWindow.message '', "Visit https://github.com/noahsug/circ/wiki to read documentation or report an issue.", "system"
    @context.currentWindow.emptyLine()
    @context.currentWindow.message '', "Type /server <server> [port] to connect, then /nick <my_nick> and /join <#channel>.", "system"
    @context.currentWindow.emptyLine()
    @context.currentWindow.message '', "Type /help to see a full list of commands.", "system"
    @context.currentWindow.emptyLine()
    @context.currentWindow.message '', "Switch windows with alt+[0-9] or clicking in the channel list on the left.", "system"

    document.title = "CIRC #{irc.VERSION}"
    @_loadStateFromStorage()

    @messageHandler = new chat.IRCMessageHandler this
    @userCommands = new chat.UserCommandHandler this
    devCommands = new chat.DeveloperCommands @userCommands
    @userCommands.merge devCommands

  _loadStateFromStorage: ->
    @previousNick = undefined
    # TODO: don't let the user do anything until we load settings
    chrome.storage.sync.get 'nick', (settings) =>
      if settings?.nick
        @previousNick = settings.nick
        @updateStatus()

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
    name = server # TODO: 'irc.freenode.net' -> 'freenode'
    if irc = @context.connections[name]?.irc
      return if irc.state in ['connected', 'connecting']
    else
      win = new chat.Window(name)
      win.message '*', "Connecting to #{server}..."
      irc = new window.irc.IRC
      conn = @context.connections[name] = {irc:irc, name, serverWindow:win, windows:{}}
      win.conn = conn
      @context.winList.add win
      @ircEvents.addEventsFrom irc
      @context.channelDisplay.add conn.name
      irc.setPreferredNick @previousNick if @previousNick?
      if @context.currentWindow == @context.emptyWindow
        @context.channelDisplay.remove @context.emptyWindow.name
        @switchToWindow win
    irc.connect(server, port)

  onIRCEvent: (e) =>
    if e.context.channel is chat.CURRENT_WINDOW and
        e.context.server isnt @context.currentWindow.conn?.name
      e.context.channel = chat.SERVER_WINDOW
    conn = @context.connections[e.context.server]
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
    if irc.util.nicksEqual chan, conn.irc.nick
      return chat.NO_WINDOW unless e.name is 'privmsg'
      from = e.args[0]
      conn.windows[from] ?= @_createWindowForChannel conn, from
      conn.windows[from].makePrivate()
      @context.channelDisplay.connect conn.name, from
      return conn.windows[from]
    if not chan or chan is chat.SERVER_WINDOW
      return conn.serverWindow
    if chan is chat.CURRENT_WINDOW
      return @context.currentWindow
    if conn.windows[chan]
      return conn.windows[chan]
    return chat.NO_WINDOW

  onConnected: (conn) ->
    @displayMessage 'connect', {server: conn.name}
    @updateStatus()
    @context.channelDisplay.connect conn.name
    for chan, win of conn.windows
      @displayMessage 'connect', {server: conn.name, channel: win.target}
      @context.channelDisplay.connect conn.name, chan if win.isPrivate()

  onDisconnected: (conn) ->
    @displayMessage 'disconnect', {server: conn.name}
    @context.channelDisplay.disconnect conn.name
    for chan, win of conn.windows
      @context.channelDisplay.disconnect conn.name, chan
      @displayMessage 'disconnect', {server: conn.name, channel: win.target}

  onJoined: (conn, chan) ->
    win = @_createWindowForChannel conn, chan
    @context.channelDisplay.connect conn.name, chan
    win.nicks.clear()

  _createWindowForChannel: (conn, chan) ->
    win = conn.windows[chan]
    if not win
      win = @makeWin conn, chan
      i = @context.winList.indexOf win
      @context.channelDisplay.insert i, conn.name, chan
    win

  onNames: (conn, chan, nicks) ->
    if win = conn.windows[chan]
      win.nicks.add(nicks...)

  onParted: (conn, chan) ->
    if win = conn.windows[chan]
      @context.channelDisplay.disconnect conn.name, chan

  removeWindow: (win=@context.currentWindow) ->
    index = @context.winList.indexOf win
    removedWindows = @context.winList.remove win
    for win in removedWindows
      @_removeWindowFromState win
    @_selectNextWindow(index)

  _removeWindowFromState: (win) ->
    @context.channelDisplay.remove win.conn.name, win.target
    if win.target?
      delete @context.connections[win.conn.name].windows[win.target]
    else
      delete @context.connections[win.conn.name]
    win.remove()

  _selectNextWindow: (preferredIndex) ->
    if @context.winList.length is 0
      @context.channelDisplay.add @context.emptyWindow.name
      @switchToWindow @context.emptyWindow
    else if @context.winList.indexOf(@context.currentWindow) == -1
      nextWin = @context.winList.get(preferredIndex) ? @context.winList.get(preferredIndex - 1)
      @switchToWindow nextWin

  makeWin: (conn, chan) ->
    throw new Error("we already have a window for that") if conn.windows[chan]
    win = conn.windows[chan] = new chat.Window(chan)
    win.conn = conn
    win.setTarget chan
    @context.winList.add win
    win

  updateStatus: ->
    statusList = []
    nick = @context.currentWindow.conn?.irc.nick ? @previousNick
    away = @context.currentWindow.conn?.irc.away
    channel = @context.currentWindow.target
    topic = @context.currentWindow.conn?.irc.channels[channel]?.topic
    statusList.push "[#{nick}]" if nick
    statusList.push "(away)" if away
    statusList.push "#{channel}" if channel
    statusList.push "- #{topic}" if topic
    statusList.push 'Welcome!' if statusList.length is 0
    $('#status').text(statusList.join ' ')

  switchToWindowByIndex: (winNum) ->
      winNum = 10 if winNum is 0
      win = @context.winList.get winNum - 1
      @switchToWindow win if win?

  switchToWindow: (win) ->
    throw new Error("switching to non-existant window") if not win?
    @context.currentWindow.detach() if @context.currentWindow
    win.attachTo @$windowContainer
    @context.currentWindow = win
    if win.conn?
      @context.channelDisplay.select win.conn.name, win.target
    else
      @context.channelDisplay.select Chat.NoConnName
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