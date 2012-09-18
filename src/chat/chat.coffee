exports = window.chat ?= {}

class Chat extends EventEmitter
  constructor: ->
    super
    @$windowContainer = $('#chat')

    @ircResponseHandler = new chat.IRCResponseHandler()
    @chatCommands = new chat.ChatCommands this
    devCommands = new chat.DeveloperCommands @chatCommands
    @chatCommands.merge devCommands

    @channelDisplay = new chat.ChannelList()
    @channelDisplay.on 'clicked', (chan) =>
      win = @_getWindowFromChan(chan)
      @switchToWindow win

    @previousNick = undefined
    # TODO: don't let the user do anything until we load settings
    chrome.storage.sync.get 'nick', (settings) =>
      if settings?.nick
        @previousNick = settings.nick

    @systemWindow = new chat.Window('system')
    @switchToWindow @systemWindow
    @winList = [@systemWindow]

    @systemWindow.message '', "Welcome to irciii, a v2 Chrome app."
    @systemWindow.message '', "Type /connect <server> [port] to connect, then /nick <my_nick> and /join <#channel>."
    @systemWindow.message '', "Alt+[0-9] switches windows."

    @updateStatus 'hi!'

    @connections = {}

  listenToUserInput: (userInput) ->
    @chatCommands.listenTo userInput
    userInput.on 'switch_window', (winNum) =>
      @switchToWindow @winList[winNum] if @winList[winNum]?

  listenToScriptEvents: (scriptEvents) ->
    # TODO
    #scriptEvents.on 'notify', @createNotification
    #scriptEvents.on 'print', @printText

  listenToIRCEvents: (@ircEvents) ->
    @ircEvents.on 'server', @onIRCEvent
    @ircEvents.on 'message', @onIRCEvent

  connect: (server, port = 6667) ->
    name = server # TODO: 'irc.freenode.net' -> 'freenode'
    if irc = @connections[name]?.irc
      return if irc.state in ['connected', 'connecting']
    else
      irc = new window.irc.IRC
      conn = @connections[name] = {irc:irc, name, windows:{}}
      @ircEvents.addEventsFrom irc
    irc.setPreferredNick @previousNick if @previousNick?
    irc.connect(server, port)
    @systemWindow.conn = conn

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
      system_handlers[type].apply @systemWindow, [conn].concat(e.args)
      return

    win = conn.windows[chan]
    if not win
      @systemWindow.message conn.name, "unknown message: #{chan}(#{type}): #{JSON.stringify e.args}"
      console.warn "message to unknown chan", conn.name, chan, type, e.args
      return

    if not @ircResponseHandler.canHandle type
      console.warn "received unknown message", conn.name, chan, type, e.args
      return

    @ircResponseHandler.setWindow(win)
    @ircResponseHandler.handle type, e.args...

  onConnected: (conn) ->
    @systemWindow.message '', "Connected to #{conn.name}"
    for chan, win of conn.windows
      win.message '', '(connected)', type:'system'

  onDisconnected: (conn) ->
    @systemWindow.message '', "Disconnected from #{conn.name}"
    for chan, win of conn.windows
      @channelDisplay.disconnect chan
      win.message '', '(disconnected)', type:'system'

  onJoined: (conn, chan) ->
    win = @_createWindowForChannel conn, chan
    @channelDisplay.connect chan
    win.nicks.clear()
    win.message '', '(You joined the channel)', type:'system'

  _createWindowForChannel: (conn, chan) ->
    win = conn.windows[chan]
    if not win
      @channelDisplay.add chan
      win = @makeWin conn, chan
    win

  onNames: (conn, chan, nicks) ->
    if win = conn.windows[chan]
      win.nicks.add(nicks...)

  onParted: (conn, chan) ->
    if win = conn.windows[chan]
      @channelDisplay.disconnect chan
      win.message '', '(You left the channel)', type:'system'

  system_handlers =
    welcome: (conn, msg) ->
      @message conn.name, msg, type: 'welcome'
    unknown: (conn, cmd) ->
      @message conn.name, cmd.command + ' ' + cmd.params.join(' ')
    nickinuse: (conn, oldnick, newnick, msg) ->
      @message conn.name, "Nickname #{oldnick} already in use: #{msg}"

  makeWin: (conn, chan) ->
    throw new Error("we already have a window for that") if conn.windows[chan]
    win = conn.windows[chan] = new chat.Window(chan)
    win.conn = conn
    win.target = chan
    @winList.push(win)
    win

  updateStatus: (status) ->
    if !status
      status = "[#{@currentWindow.conn?.irc.nick}] #{@currentWindow.target}"
    $('#status').text(status)

  switchToWindow: (win) ->
    throw new Error("switching to non-existant window") if not win?
    @currentWindow.detach() if @currentWindow
    win.attachTo @$windowContainer
    @currentWindow = win
    @channelDisplay.select win.target
    @updateStatus()

  _getWindowFromChan: (chan) ->
    for win in @winList
      return win if win.target == chan
    undefined

exports.Chat = Chat