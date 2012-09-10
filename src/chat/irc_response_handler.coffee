exports = window.chat ?= {}

class IRCResponseHandler extends MessageHandler
  constructor: (@chat) ->
    super
    @registerHandlers @_ircResponses

  setWindow: (@window) ->

  _ircResponses:
    join: (nick) ->
      @window.message '', "#{nick} joined the channel.", type:'join'
      @window.nicks.add nick

    part: (nick) ->
      @window.message '', "#{nick} left the channel.", type:'part'
      @window.nicks.remove nick

    nick: (from, to) ->
      @window.message '', "#{from} is now known as #{to}.", type:'nick'
      @window.nicks.replace from, to

    quit: (nick, reason) ->
      @window.message '', "#{nick} has quit: #{reason}.", type:'quit'
      @window.nicks.remove nick

    privmsg: (from, msg) ->
      nick = @window.conn?.irc.nick
      ownMessage = irc.util.nicksEqual from, nick
      if not ownMessage and chat.NickMentionedNotification.shouldNotify(nick, msg)
        # TODO color text where nick is mentioned so it stands out
        @_notifyNickMentioned from, msg
      if m = /^\u0001ACTION (.*)\u0001/.exec msg
        @window.message '', "#{from} #{m[1]}", type:'privmsg action'
      else
        @window.message from, msg, type:'privmsg'

  _notifyNickMentioned: (from, msg) ->
    #TODO cancel notification when focus is gained on the channel
    #TODO add callback to focus conversation when user clicks on notification
    notification = new chat.NickMentionedNotification(from, msg)
    notification.show()

exports.IRCResponseHandler = IRCResponseHandler
