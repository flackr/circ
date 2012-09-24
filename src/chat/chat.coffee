exports = window.chat ?= {}

class Chat extends EventEmitter
  @NoConnName = 'none'

  constructor: ->
    super
    @$windowContainer = $('#chat')

    @ircResponseHandler = new chat.IRCResponseHandler
    @chatCommands = new chat.ChatCommands this
    devCommands = new chat.DeveloperCommands @chatCommands
    @chatCommands.merge devCommands

    @channelDisplay = new chat.ChannelList()
    @channelDisplay.on 'clicked', (server, chan) =>
      win = @winList.get server, chan
      @switchToWindow win if win?

    @previousNick = undefined
    # TODO: don't let the user do anything until we load settings
    chrome.storage.sync.get 'nick', (settings) =>
      if settings?.nick
        @previousNick = settings.nick

    @channelDisplay.add Chat.NoConnName
    @switchToWindow new chat.Window Chat.NoConnName
    @winList = new chat.WindowList()

    @currentWindow.message '*', "Welcome to CIRC, a packaged Chrome app.", "circ"
    @currentWindow.message '*', "Type /server <server> [port] to connect, then /nick <my_nick> and /join <#channel>.", "circ"
    @currentWindow.message '*', "Switch windows with alt+[0-9] or clicking in the channel list on the left.", "circ"

    @updateStatus()

    @connections = {}

  listenToUserInput: (userInput) ->
    @chatCommands.listenTo userInput
    userInput.on 'switch_window', (winNum) =>
      win = @winList.getChannelWindow winNum - 1
      @switchToWindow win if win?

  listenToScriptEvents: (@scriptHandler) ->
    # TODO
    #scriptHandler.on 'notify', @createNotification
    #scriptHandler.on 'print', @printText

  listenToIRCEvents: (@ircEvents) ->
    @ircEvents.on 'server', @onIRCEvent
    @ircEvents.on 'message', @onIRCEvent

  connect: (server, port = 6667) ->
    name = server # TODO: 'irc.freenode.net' -> 'freenode'
    if irc = @connections[name]?.irc
      return if irc.state in ['connected', 'connecting']
    else
      win = @currentWindow
      if win.name == Chat.NoConnName
        @channelDisplay.remove Chat.NoConnName
        win.name = name
      else
        win = new chat.Window(name)
      irc = new window.irc.IRC
      conn = @connections[name] = {irc:irc, name, serverWindow:win, windows:{}}
      win.conn = conn
      @winList.add win
      @ircEvents.addEventsFrom irc
      @channelDisplay.add conn.name
      irc.setPreferredNick @previousNick if @previousNick?
      if win == @currentWindow
        @updateStatus()
        @channelDisplay.select name
    irc.connect(server, port)

  onIRCEvent: (e) =>
    conn = @connections[e.context.server]
    if not conn?
      console.warn 'got event', e.type, e.name, 'on unknown connection', e.context.server
      return
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
    chan = e.context.channel
    type = e.name
    if not chan?
      system_handlers[type].apply conn.serverWindow, [conn].concat(e.args)
      return

    win = conn.windows[chan]
    if not win
      console.warn "message to unknown chan", conn.name, chan, type, e.args
      return

    if not @ircResponseHandler.canHandle type
      console.warn "received unknown message", conn.name, chan, type, e.args
      return

    @ircResponseHandler.setWindow(win)
    @ircResponseHandler.setStyle(e.style)
    @ircResponseHandler.handle type, e.args...

  onConnected: (conn) ->
    @emitMessage 'connect', conn.name
    @channelDisplay.connect conn.name
    for chan, win of conn.windows
      @emitMessage 'connect', conn.name, win.target

  onDisconnected: (conn) ->
    @emitMessage 'disconnect', conn.name
    @channelDisplay.disconnect conn.name
    for chan, win of conn.windows
      @channelDisplay.disconnect conn.name, chan
      @emitMessage 'disconnect', conn.name, win.target

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
    if win = conn.windows[chan]
      win.nicks.add(nicks...)

  onParted: (conn, chan) ->
    if win = conn.windows[chan]
      @channelDisplay.disconnect conn.name, chan

  system_handlers =
    welcome: (conn, msg) ->
      @message '*', msg, 'welcome'
    unknown: (conn, cmd) ->
      @message '*', cmd.command + ' ' + cmd.params.join(' ')
    nickinuse: (conn, oldnick, newnick, msg) ->
      @message '*', "Nickname #{oldnick} already in use: #{msg}"
    connect: ->
      @message '*', "Connected. Now logging in..."
    disconnect: ->
      @message '*', "Disconnected"

  makeWin: (conn, chan) ->
    throw new Error("we already have a window for that") if conn.windows[chan]
    win = conn.windows[chan] = new chat.Window(chan)
    win.conn = conn
    win.setTarget chan
    @winList.add win
    win

  updateStatus: (status) ->
    if !status
      nick = @currentWindow.conn?.irc.nick ? @currentWindow.conn?.irc.preferredNick
      status = "[#{nick}] #{@currentWindow.target ? ''}"
    $('#status').text(status)

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

  emitMessage: (name, server, channel, args...) ->
    event = new Event 'message', name, args...
    event.setContext server, channel
    @emit event.type, event

exports.Chat = Chat