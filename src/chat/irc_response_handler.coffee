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
        @_message '*', 'No topic is set', 'circ'
      else if not from
        @_message '*', "The topic is: #{topic}", 'circ'
      else if @_isOwnNick from
        @_message '*', "(You changed the topic to: #{topic})", 'system'
      else
        @_message '*', "#{from} changed the topic to: #{topic}", 'system_other'

    join: (nick) ->
      if @_isOwnNick nick
        @_message '*', "(You joined the channel)", 'system'
      else
        @_message '*', "#{nick} joined the channel.", 'join'
      @win.nicks.add nick

    part: (nick) ->
      if @_isOwnNick nick
        @_message '*', "(You left the channel)", 'system'
      else
        @_message '*', "#{nick} left the channel.", 'part'
      @win.nicks.remove nick

    nick: (from, to) ->
      if @_isOwnNick to
        @chat.updateStatus()
        @_message '*', "(You are now known as #{to})", 'system'
      else
        @_message '*', "#{from} is now known as #{to}.", 'nick'
      @win.nicks.replace from, to

    quit: (nick, reason) ->
      if not @_isOwnNick nick
        @_message '*', "#{nick} has quit: #{reason}.", 'quit'
        @win.nicks.remove nick

    disconnect: ->
      @_message '*', '(Disconnected)', 'system'

    connect: ->
      @_message '*', '(Connected)', 'system'

    privmsg: (from, msg) ->
      nick = @win.conn.irc.nick
      style = []
      nickMentioned = not @_isOwnNick(from) and
        chat.NickMentionedNotification.shouldNotify(nick, msg)
      @_handleNotifications from, msg, nickMentioned

      style.push 'mention' if nickMentioned
      style.push 'self' if @_isOwnNick(from)
      if m = /^\u0001ACTION (.*)\u0001/.exec msg
        @_message '*', "#{from} #{m[1]}", 'privmsg action', style...
      else
        @_message from, msg, 'privmsg', style...

    system: (text) ->
      @_message '*', text, 'server'

  _handleNotifications: (from, msg, nickMentioned) ->
    return if @win.target is @chat.currentWindow.target
    @chat.channelDisplay.activity @win.conn.name, @win.target
    if nickMentioned
      @_notifyNickMentioned from, msg if not window.document.hasFocus()
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
