exports = window.chat ?= {}

class ChatCommands extends MessageHandler
  constructor: (@chat) ->
    super

  getCommands: ->
    Object.keys @_handlers

  listenTo: (emitter) ->
    emitter.on 'command', (e) =>
      if @canHandle e.name
        @handle e.name, e.args...

  _handlers:
    join: (opt_chan) ->
      if conn = @chat.currentWindow.conn
        return if not (conn.irc.state is 'connected')
        chan = opt_chan ? @chat.currentWindow.target
        return if not chan
        win = @chat._createWindowForChannel conn, chan
        @chat.switchToWindow win
        @chat.currentWindow.conn.irc.doCommand 'JOIN', chan

    win: (num) ->
      num = parseInt(num)
      win = @chat.winList.get num
      @chat.switchToWindow win if win?

    say: (text...) ->
      if (target = @chat.currentWindow.target) and (conn = @chat.currentWindow.conn)
        text = text.join ' '
        event = new Event 'message', 'privmsg', conn.irc.nick, text
        event.setContext conn.name, target
        @chat.onMessageEvent conn, event
        conn.irc.doCommand 'PRIVMSG', target, text

    me: (text...) ->
      text = text.join ' '
      @chat.chatCommands.handle 'say', '\u0001ACTION '+text+'\u0001'

    nick: (newNick) ->
      if conn = @chat.currentWindow.conn
        # TODO: HRHRMRHM
        chrome.storage.sync.set({nick: newNick})
        conn.irc.doCommand 'NICK', newNick

    connect: -> @handle 'server', arguments...
    server: (server, port) -> # connect to server
      server ?= @chat.currentWindow.conn?.name
      if server?
        @chat.connect server, if port then parseInt port

    quit: (reason...) ->
      if conn = @chat.currentWindow.conn
        # TODO handle case where irc is connecting
        return unless conn.irc.state in ['reconnecting', 'connected']
        if conn.irc.state == 'reconnecting'
          conn.irc.giveup()
        else
          reason = if reason.length == 0 then 'Client Quit' else reason.join(' ')
          conn.irc.quit reason
        @chat.removeWindow @chat.winList.get conn.name

    names: ->
      if (conn = @chat.currentWindow.conn) and
         (target = @chat.currentWindow.target) and
         (names = conn.irc.channels[target]?.names)
        names = (v for k,v of names).sort()
        @chat.currentWindow.message '*', JSON.stringify names

    help: ->
      commands = @chat.chatCommands.getCommands()
      @chat.currentWindow.displayHelp commands

    part: (reason...) ->
      win = @chat.currentWindow
      if (conn = win.conn) and (target = win.target)
        conn.irc.doCommand 'PART', target, reason.join(' ')
        @chat.removeWindow()

    do: (args...) ->
      start = 0
      if (conn = @chat.currentWindow.conn)
        channel = @chat.currentWindow.target
        ircCommand = chat.customCommandParser.parse channel, args...
        conn.irc.doCommand ircCommand...

    load: ->
      script.loader.createScriptFromFileSystem (script) =>
        @chat.emit 'script_loaded', script

exports.ChatCommands = ChatCommands