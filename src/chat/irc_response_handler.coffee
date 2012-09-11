exports = window.chat ?= {}

class IRCResponseHandler extends MessageHandler
  constructor: (@chat) ->
    super
    @registerHandlers @_ircResponses

  setWindow: (@win) ->

  _ircResponses:
    join: (nick) ->
      @win.message '', "#{nick} joined the channel.", type:'join'
      @win.nicks.add nick

    part: (nick) ->
      @win.message '', "#{nick} left the channel.", type:'part'
      @win.nicks.remove nick

    nick: (from, to) ->
      @win.message '', "#{from} is now known as #{to}.", type:'nick'
      @win.nicks.replace from, to

    quit: (nick, reason) ->
      @win.message '', "#{nick} has quit: #{reason}.", type:'quit'
      @win.nicks.remove nick

    privmsg: (from, msg) ->
      nick = @win.conn?.irc.nick
      ownMessage = irc.util.nicksEqual from, nick
      if not ownMessage and chat.NickMentionedNotification.shouldNotify(nick, msg)
        # TODO color text where nick is mentioned so it stands out
        @_notifyNickMentioned from, msg
      if m = /^\u0001ACTION (.*)\u0001/.exec msg
        @win.message '', "#{from} #{m[1]}", type:'privmsg action'
      else
        @win.message from, msg, type:'privmsg'

  _notifyNickMentioned: (from, msg) ->
    #TODO cancel notification when focus is gained on the channel
    #TODO add callback to focus conversation when user clicks on notification
    notification = new chat.NickMentionedNotification(from, msg)
    notification.show()

exports.IRCResponseHandler = IRCResponseHandler
