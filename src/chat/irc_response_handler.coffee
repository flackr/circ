exports = window.chat ?= {}

class IRCResponseHandler extends MessageHandler
  constructor: (@chat) ->
    super

  setWindow: (@win) ->

  setStyle: (@style) ->

  _handlers:
    topic: (topic, from) ->
      @chat.updateStatus()
      if not topic
        @_message '*', 'No topic is set', 'notice topic'
      else if not from
        @_message '*', "The topic is: #{topic}", 'notice topic'
      else if @_isOwnNick from
        @_message '*', "(You changed the topic to: #{topic})", 'self update topic'
      else
        @_message '*', "#{from} changed the topic to: #{topic}", 'update topic'

    join: (nick) ->
      if @_isOwnNick nick
        @_message '*', "(You joined the channel)", 'self update join'
      else
        @_message '*', "#{nick} joined the channel.", 'update join'
      @win.nicks.add nick

    part: (nick) ->
      if @_isOwnNick nick
        @_message '*', "(You left the channel)", 'self update part'
      else
        @_message '*', "#{nick} left the channel.", 'update part'
      @win.nicks.remove nick

    kick: (from, to, reason) ->
      if @_isOwnNick from
        @_message '*', "(You kicked #{to} from the channel: #{reason})", 'self update kick'
      else
        to = "you" if @_isOwnNick to
        @_message '*', "#{from} kicked #{to} from the channel: #{reason}.", 'update kick'
      @win.nicks.remove to

    nick: (from, to) ->
      if @_isOwnNick to
        @chat.updateStatus()
        @_message '*', "(You are now known as #{to})", 'self update nick'
      else
        @_message '*', "#{from} is now known as #{to}.", 'update nick'
      @win.nicks.replace from, to

    quit: (nick, reason) ->
      if not @_isOwnNick nick
        @_message '*', "#{nick} has quit: #{reason}.", 'self update quit'
        @win.nicks.remove nick

    disconnect: ->
      @_message '*', '(Disconnected)', 'self update disconnect'

    connect: ->
      @_message '*', '(Connected)', 'self update connect'

    privmsg: (from, msg) ->
      nick = @win.conn.irc.nick
      nickMentioned = not @_isOwnNick(from) and
        chat.NickMentionedNotification.shouldNotify(nick, msg)
      @_handleNotifications from, msg, nickMentioned

      style = ['update privmsg']
      style.push 'mention' if nickMentioned
      style.push 'self' if @_isOwnNick(from)
      if m = /^\u0001ACTION (.*)\u0001/.exec msg
        @_message '*', "#{from} #{m[1]}", 'action', style...
      else
        @_message from, msg, style...

    error: (msg) ->
      @_message '*', msg, 'notice error'

  _handleNotifications: (from, msg, nickMentioned) ->
    if nickMentioned
      @_notifyNickMentioned from, msg if not window.document.hasFocus()

    return if @win.target is @chat.currentWindow.target
    @chat.channelDisplay.activity @win.conn.name, @win.target
    if nickMentioned
      @chat.channelDisplay.mention @win.conn.name, @win.target

  _message: (from, msg, style...) ->
    @win.message from, msg, style..., @style...

  _notifyNickMentioned: (from, msg) ->
    #TODO cancel notification when focus is gained on the channel
    #TODO add callback to focus conversation when user clicks on notification
    notification = new chat.NickMentionedNotification(@win.target, from, msg)
    notification.show()

  _isOwnNick: (nick) ->
    return irc.util.nicksEqual @win.conn?.irc.nick, nick

exports.IRCResponseHandler = IRCResponseHandler
