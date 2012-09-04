exports = window.chat ?= {}

class IRCResponseHandler extends AbstractMessageHandler
  setWindow: (@window) ->
    @_message = @window.message

  handlers:
    join: (nick) ->
      @_message '', "#{nick} joined the channel.", type:'join'

    part: (nick) ->
      @_message '', "#{nick} left the channel.", type:'part'

    nick: (from, to) ->
      @_message '', "#{from} is now known as #{to}.", type:'nick'

    quit: (nick, reason) ->
      @_message '', "#{nick} has quit: #{reason}.", type:'quit'

    privmsg: (from, msg) ->
      nick = @window.conn?.irc.nick
      if chat.NickMentionedRegex.shouldNotify(nick, msg)
        @_notifyNickMentioned from, msg
      if m = /^\u0001ACTION (.*)\u0001/.exec msg
        @_message '', "#{from} #{m[1]}", type:'privmsg action'
      else
        @_message from, msg, type:'privmsg'

    _notifyNickMentioned: (from, msg) ->
      #TODO add callback to focus conversation where mentioned
      notification = new NickMentionedNotification(from, msg)
      notification.show()

exports.IRCResponseHandler = IRCResponseHandler
