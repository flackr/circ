exports = window.chat ?= {}

class IRCResponseHandler extends MessageHandler
  constructor: (@chat) ->
    @formatter = new MessageFormatter
    super

  setWindow: (@win) ->
    @formatter.setNick @win.conn?.irc.nick

  setStyle: (additionalStyle) ->
    @formatter.setAdditionalStyle additionalStyle

  handle: (type, params) ->
    @source = '*'
    @formatter.clear()
    @formatter.setStyle 'update'
    @formatter.setFromToWhat params...
    super type, params
    @_sendFormattedMessage()

  _handlers:
    topic: (from, topic) ->
      @chat.updateStatus()
      @formatter.setFromToWhat from, undefined, topic
      @formater.setStyle = 'notice'
      if not topic
        @formatter.setMessage 'no topic is set'
      else if not from
        @formatter.setMessage 'the topic is: #what'
      else
        @formatter.setMessage '#from changed the topic to: #what'

    join: (nick) ->
      @formatter.setMessage '#from joined the channel'
      @win.nicks.add nick

    part: (nick) ->
      @formatter.setMessage '#from left the channel'
      @win.nicks.remove nick

    kick: (from, to, reason) ->
      @formatter.setMessage '#from kicked #to from the channel: #what'
      @win.nicks.remove to

    nick: (from, to) ->
      ownNick = @_isOwnNick to
      @formatter.setMessage '#from is now known as #to'
      @formatter.force
      @chat.updateStatus() if ownNick
      @win.nicks.replace from, to

    mode: (from, to, mode) ->
      # TODO handle other modes besides just +o
      @formatter.setMessage '#from gave channel operator status to #to'
      @_fromToWhatMessage msg, 'topic', from, to, mode

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

  _sendFormattedMessage: ->
    @formatter.addStyle @type
    @win.message @source, @formatter.format(), @formatter.getStyle()

  _notifyNickMentioned: (from, msg) ->
    #TODO cancel notification when focus is gained on the channel
    #TODO add callback to focus conversation when user clicks on notification
    notification = new chat.NickMentionedNotification(@win.target, from, msg)
    notification.show()

  _isOwnNick: (nick) ->
    irc.util.nicksEqual @win.conn?.irc.nick, nick

exports.IRCResponseHandler = IRCResponseHandler
