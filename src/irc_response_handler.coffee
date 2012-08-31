exports = window.chat ?= {}

class IRCResponseHandler extends AbstractMessageHandler
  handlers:
    join: (nick) ->
      @message '', "#{nick} joined the channel.", type:'join'
    part: (nick) ->
      @message '', "#{nick} left the channel.", type:'part'
    nick: (from, to) ->
      @message '', "#{from} is now known as #{to}.", type:'nick'
    quit: (nick, reason) ->
      @message '', "#{nick} has quit: #{reason}.", type:'quit'
    privmsg: (from, msg) ->
      if m = /^\u0001ACTION (.*)\u0001/.exec msg
        @message '', "#{from} #{m[1]}", type:'privmsg action'
      else
        @message from, msg, type:'privmsg'

exports.IRCResponseHandler = IRCResponseHandler
