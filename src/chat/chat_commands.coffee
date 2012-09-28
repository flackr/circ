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
        return unless (conn.irc.state is 'connected')
        chan = opt_chan ? @chat.currentWindow.target
        return unless chan
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
        conn.irc.doCommand 'PRIVMSG', target, text
        @chat.displayMessage 'privmsg', conn.name, target, conn.irc.nick, text

    me: (text...) ->
      text = text.join ' '
      @chat.chatCommands.handle 'say', '\u0001ACTION '+text+'\u0001'

    nick: (newNick) ->
      @chat.previousNick = newNick
      chrome.storage.sync.set({nick: newNick})
      @chat.updateStatus()
      if conn = @chat.currentWindow.conn
        conn.irc.doCommand 'NICK', newNick

    connect: -> @handle 'server', arguments...
    server: (server, port) -> # connect to server
      server ?= @chat.currentWindow.conn?.name
      if server?
        @chat.connect server, if port then parseInt port

    quit: (reason...) ->
      return unless (conn = @chat.currentWindow.conn)
      if conn.irc.state == 'reconnecting'
        conn.irc.giveup()
      else
        reason = if reason.length is 0 then 'Client Quit' else reason.join(' ')
        conn.irc.quit reason
      @chat.removeWindow @chat.winList.get conn.name

    names: ->
      win = @chat.currentWindow
      return unless (conn = win.conn) and (target = win.target) and
          (names = conn.irc.channels[target]?.names)
      names = (v for k,v of names).sort()
      msg = "Users in #{target}: #{JSON.stringify names}"
      @chat.currentWindow.message '*', msg, 'notice names'

    help: ->
      commands = @chat.chatCommands.getCommands()
      @chat.currentWindow.displayHelp commands

    part: (reason...) ->
      win = @chat.currentWindow
      if (conn = win.conn) and (target = win.target)
        conn.irc.doCommand 'PART', target, reason.join(' ')
        @chat.removeWindow()

    raw: (args...) ->
      start = 0
      if (conn = @chat.currentWindow.conn)
        channel = @chat.currentWindow.target
        ircCommand = chat.customCommandParser.parse channel, args...
        conn.irc.doCommand ircCommand...

    load: ->
      script.loader.createScriptFromFileSystem (script) =>
        @chat.emit 'script_loaded', script

    topic: (topic...) ->
      win = @chat.currentWindow
      return unless (conn = win.conn) and (target = win.target)
      conn.irc.doCommand 'TOPIC', target, topic.join ' '

    kick: (nick, reason...) ->
      win = @chat.currentWindow
      return unless (conn = win.conn) and (chan = win.target)
      conn.irc.doCommand 'KICK', chan, nick, reason.join ' '

    ##
    # /msg sends a direct message to another user. If their exists a private
    # chat room between the two users, the message will go there. Otherwise
    # it is displayed in the current window.
    ##
    msg: (to, message...) ->
      return unless (conn = @chat.currentWindow.conn)
      message = message.join ' '
      conn.irc.doCommand 'PRIVMSG', to, message
      @_displayDirectMessage to, message

  _displayDirectMessage: (to, message) ->
    conn = @chat.currentWindow.conn
    e = new Event 'message', 'privmsg', to, message
    e.setContext conn.name, @chat.currentWindow.target
    e.setStyle 'direct'
    @chat.emit e.type, e

exports.ChatCommands = ChatCommands