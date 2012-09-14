exports = window.chat ?= {}

class ChatCommands extends MessageHandler
  constructor: (source) ->
    super source
    @registerHandlers @_chatCommands

  getCommands: ->
    Object.keys @_chatCommands

  listenTo: (emitter) ->
    emitter.on 'command', (server, channel, command, args...) =>
      if @canHandle command
        @handle command, args...

  _chatCommands:
    join: (opt_chan) ->
      if conn = @currentWindow.conn
        return if not (conn.irc.state is 'connected')
        chan = opt_chan ? @currentWindow.target
        return if not chan
        win = @_createWindowForChannel conn, chan
        @switchToWindow win
        @currentWindow.conn.irc.doCommand 'JOIN', chan

    win: (num) ->
      num = parseInt(num)
      @switchToWindow @winList[num] if num < @winList.length

    say: (text...) ->
      if (target = @currentWindow.target) and (conn = @currentWindow.conn)
        msg = text.join(' ')
        @onIRCMessage conn, target, 'privmsg', conn.irc.nick, msg
        conn.irc.doCommand 'PRIVMSG', target, msg

    me: (text...) ->
      commands.say.call this, '\u0001ACTION '+text.join(' ')+'\u0001'

    nick: (newNick) ->
      if conn = @currentWindow.conn
        # TODO: HRHRMRHM
        chrome.storage.sync.set({nick: newNick})
        conn.irc.doCommand 'NICK', newNick

    server: (server, port) -> # connect to server
      @connect server, if port then parseInt port

    quit: (reason...) ->
      if conn = @currentWindow.conn
        reason = if reason.length == 0 then 'Client Quit' else reason.join(' ')
        conn.irc.quit reason

    names: ->
      if (conn = @currentWindow.conn) and
         (target = @currentWindow.target) and
         (names = conn.irc.channels[target]?.names)
        names = (v for k,v of names).sort()
        @currentWindow.message '', JSON.stringify names

    help: ->
      commands = @chatCommands.getCommands()
      @currentWindow.displayHelp commands

    part: (reason...) ->
      if (conn = @currentWindow.conn) and
         (target = @currentWindow.target)
        conn.irc.doCommand 'PART', target, reason.join(' ')

    load: ->
      frame = script.loader.loadIntoFrameFromFileSystem (frame) =>
        @emit 'script_loaded', frame

chat.ChatCommands = ChatCommands