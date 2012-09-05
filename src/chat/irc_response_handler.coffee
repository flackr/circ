exports = window.chat ?= {}

class IRCResponseHandler extends AbstractMessageHandler
  setWindow: (@window) ->

  handlers:
    join: (nick) ->
      @window.message '', "#{nick} joined the channel.", type:'join'

    part: (nick) ->
      @window.message '', "#{nick} left the channel.", type:'part'

    nick: (from, to) ->
      @window.message '', "#{from} is now known as #{to}.", type:'nick'

    quit: (nick, reason) ->
      @window.message '', "#{nick} has quit: #{reason}.", type:'quit'

    privmsg: (from, msg) ->
      nick = @window.conn?.irc.nick
      ownMessage = from? and nick? and irc.util.nicksEqual from, nick
      if not ownMessage and chat.NickMentionedNotification.shouldNotify(nick, msg)
        @_notifyNickMentioned from, msg
      if m = /^\u0001ACTION (.*)\u0001/.exec msg
        @window.message '', "#{from} #{m[1]}", type:'privmsg action'
      else
        @window.message from, msg, type:'privmsg'

  _notifyNickMentioned: (from, msg) ->
    #TODO add callback to focus conversation where mentioned
    notification = new chat.NickMentionedNotification(from, msg)
    notification.show()

exports.IRCResponseHandler = IRCResponseHandler
