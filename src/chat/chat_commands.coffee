exports = window.chat ?= {}

class ChatCommands extends AbstractMessageHandler
  getCommands: ->
    Object.keys @handlers

  handlers:
    join: (chan) ->
      if conn = @currentWindow.conn
        @currentWindow.conn.irc.doCommand 'JOIN', chan
        win = @makeWin @currentWindow.conn, chan
        @switchToWindow win

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
        conn.irc.quit reason.join(' ')

    names: ->
      if (conn = @currentWindow.conn) and
         (target = @currentWindow.target) and
         (names = conn.irc.channels[target]?.names)
        names = (v for k,v of names).sort()
        @currentWindow.message '', JSON.stringify names

    help: ->
      commands = @chatCommands.getCommands()
      @currentWindow.displayHelp commands

chat.ChatCommands = ChatCommands