exports = window.chat ?= {}

class IRC5
  constructor: ->
    @$main = $('#main')
    @ircResponseHandler = new chat.IRCResponseHandler()
    @chatCommands = new chat.ChatCommands(this)
    @default_nick = undefined
    # TODO: don't let the user do anything until we load settings
    chrome.storage.sync.get 'nick', (settings) =>
      if settings?.nick
        @default_nick = settings.nick

    @systemWindow = new chat.Window('system')
    @switchToWindow @systemWindow
    @winList = [@systemWindow]

    @systemWindow.message '', "Welcome to irciii, a v2 Chrome app."
    @systemWindow.message '', "Type /connect <server> [port] to connect, then /nick <my_nick> and /join <#channel>."
    @systemWindow.message '', "Alt+[0-9] switches windows."

    @status 'hi!'

    @connections = {}
    # { 'freenode': { irc: irc.IRC, windows: {Window} } }

  connect: (server, port = 6667) ->
    name = server # TODO: 'irc.freenode.net' -> 'freenode'
    tries = 0
    while @connections[name]
      name = server + ++tries
    c = new irc.IRC server, port, {nick: @default_nick}

    conn = @connections[name] = {irc:c, name, windows:{}}
    c.on 'connect', => @onConnected conn
    c.on 'disconnect', => @onDisconnected conn
    c.on 'message', (target, type, args...) =>
      @onIRCMessage conn, target, type, args...
    c.on 'joined', (chan) => @onJoined conn, chan
    c.on 'parted', (chan) => @onJoined conn, chan
    c.connect()
    @systemWindow.conn = conn

  onConnected: (conn) ->
    @systemWindow.message '', "Connected to #{conn.name}"
    for chan, win of conn.windows
      win.message '', '(connected)', type:'system'

  onDisconnected: (conn) ->
    @systemWindow.message '', "Disconnected from #{conn.name}"
    for chan, win of conn.windows
      win.message '', '(disconnected)', type:'system'

  onJoined: (conn, chan) ->
    unless win = conn.windows[chan]
      win = @makeWin conn, chan
    win.message '', '(You joined the channel.)', type:'system'

  onParted: (conn, chan) ->
    if win = conn.windows[chan]
      win.message '', '(You left the channel.)', type:'system'

  onIRCMessage: (conn, target, type, args...) =>
    if not target?
      system_handlers[type].apply @systemWindow, [conn].concat(args)
      return

    win = conn.windows[target]
    if not win
      @systemWindow.message conn.name, "unknown message: #{target}(#{type}): #{JSON.stringify args}"
      console.warn "message to unknown target", conn.name, target, type, args
      return

    if not @ircResponseHandler.canHandle type
      console.warn "received unknown message", conn.name, target, type, args
      return

    @ircResponseHandler.setSource win
    @ircResponseHandler.handle type, args...

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

  status: (status) ->
    if !status
      status = "[#{@currentWindow.conn?.irc.nick}] #{@currentWindow.target}"
    $('#status').text(status)

  switchToWindow: (win) ->
    if @currentWindow
      @currentWindow.scroll = @currentWindow.$container.scrollTop()
      @currentWindow.wasScrolledDown = @currentWindow.isScrolledDown()
      @currentWindow.$container.detach()
    @$main.append win.$container
    if win.wasScrolledDown
      win.scroll = win.$container[0].scrollHeight
    win.$container.scrollTop(win.scroll)
    @currentWindow = win
    @status()

  onTextInput: (text) ->
    if text[0] == '/'
      cmd = text[1..].split(/\s+/)
      type = cmd[0].toLowerCase()
      if @chatCommands.canHandle type
        @chatCommands.handle type, cmd[1..]...
      else
        console.log "no such command"
    else
      @chatCommands.handle 'say', text

exports.IRC5 = IRC5