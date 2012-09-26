exports = window.chat ?= {}

class Chat extends EventEmitter

  constructor: ->
    super
    @$windowContainer = $('#chat')

    @ircResponseHandler = new chat.IRCResponseHandler this
    @systemMessageHandler = new chat.SystemMessageHandler this
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
        @updateStatus()

    @emptyWindow = new chat.Window 'none'
    @channelDisplay.add @emptyWindow.name
    @switchToWindow @emptyWindow
    @winList = new chat.WindowList()

    @currentWindow.message '*', "Welcome to CIRC, a packaged Chrome app. Visit https://github.com/noahsug/ircv to file a bug or feature request.", "circ"
    @currentWindow.message '*', "Type /server <server> [port] to connect, then /nick <my_nick> and /join <#channel>. Type /help to see a full list of commands.", "circ"
    @currentWindow.message '*', "Switch windows with alt+[0-9] or clicking in the channel list on the left.", "circ"

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
      win = new chat.Window(name)
      win.message '*', "Connecting to #{server}..."
      irc = new window.irc.IRC
      conn = @connections[name] = {irc:irc, name, serverWindow:win, windows:{}}
      win.conn = conn
      @winList.add win
      @ircEvents.addEventsFrom irc
      @channelDisplay.add conn.name
      irc.setPreferredNick @previousNick if @previousNick?
      if @currentWindow == @emptyWindow
        @channelDisplay.remove @emptyWindow.name
        @switchToWindow win
    irc.connect(server, port)

  onIRCEvent: (e) =>
    conn = @connections[e.context.server]
    if not conn?
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
      if @systemMessageHandler.canHandle type
        @systemMessageHandler.handle type, conn, e.args...
      else
        console.warn "received unknown system message", conn.name, type, e.args
      return

    win = conn.windows[chan]
    if not win
      return

    if not @ircResponseHandler.canHandle type
      console.warn "received unknown message", conn.name, chan, type, e.args
      return

    @ircResponseHandler.setWindow(win)
    @ircResponseHandler.setStyle(e.style)
    @ircResponseHandler.handle type, e.args...

  onConnected: (conn) ->
    @displayMessage 'connect', conn.name
    @updateStatus()
    @channelDisplay.connect conn.name
    for chan, win of conn.windows
      @displayMessage 'connect', conn.name, win.target

  onDisconnected: (conn) ->
    @displayMessage 'disconnect', conn.name
    @channelDisplay.disconnect conn.name
    for chan, win of conn.windows
      @channelDisplay.disconnect conn.name, chan
      @displayMessage 'disconnect', conn.name, win.target

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

  removeWindow: (win=@currentWindow) ->
    index = @winList.indexOf win
    removedWindows = @winList.remove win
    for win in removedWindows
      @_eraseWindow win
    @_selectNextWindow(index)

  _eraseWindow: (win) ->
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
    win = conn.windows[chan] = new chat.Window(chan)
    win.conn = conn
    win.setTarget chan
    @winList.add win
    win

  updateStatus: (status) ->
    unless status
      status = ''
      nick = @currentWindow.conn?.irc.nick ? @previousNick
      channel = @currentWindow.target
      topic = @currentWindow.conn?.irc.channels[channel]?.topic
      status += "[#{nick}] " if nick?
      status += "#{channel} " if channel?
      status += "- #{topic}" if topic?
      status = 'Welcome!' if status == ''
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

  # emits message to script handler, which decides if it should send it back
  displayMessage: (name, server, channel, args...) ->
    event = new Event 'message', name, args...
    event.setContext server, channel
    @emit event.type, event

exports.Chat = Chat