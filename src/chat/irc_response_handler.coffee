exports = window.chat ?= {}

class IRCResponseHandler extends MessageHandler
  constructor: (@chat) ->
    @formatter = new window.chat.MessageFormatter
    super

  setWindow: (@win) ->
    @formatter.setNick @win.conn?.irc.nick

  setStyle: (customStyle) ->
    @formatter.setCustomStyle customStyle

  handle: (type, params...) ->
    @_setDefaultValues params
    super type, params...
    @_sendFormattedMessage()

  _setDefaultValues: (params) ->
    @source = '*'
    @formatter.clear()
    @formatter.setStyle 'update'
    @formatter.setContext params...

  _handlers:
    topic: (from, topic) ->
      @chat.updateStatus()
      @formatter.setContent topic
      if not topic
        @formatter.setStyle 'notice'
        @formatter.setMessage 'no topic is set'
      else if not from
        @formatter.setStyle 'notice'
        @formatter.setMessage 'the topic is: #content'
      else
        @formatter.setMessage '#from changed the topic to: #content'

    join: (nick) ->
      @formatter.setMessage '#from joined the channel'
      @win.nicks.add nick

    part: (nick) ->
      @formatter.setMessage '#from left the channel'
      @win.nicks.remove nick

    kick: (from, to, reason) ->
      @formatter.setMessage '#from kicked #to from the channel: #content'
      @win.nicks.remove to

    nick: (from, to) ->
      @formatter.setMessage '#from is now known as #to'
      @formatter.setFromUs true
      @formatter.setToUs false
      @chat.updateStatus() if @_isOwnNick to
      @win.nicks.replace from, to

    mode: (from, to, mode) ->
      @formatter.setContent @_getMode mode
      @formatter.setMessage '#from gave #content status to #to'

    quit: (nick, reason) ->
      @formatter.setMessage '#from has quit: #content'
      @formatter.setContent reason
      @win.nicks.remove nick

    disconnect: ->
      @formatter.setMessage 'Disconnected'
      @formatter.setFromUs true

    connect: ->
      @formatter.setMessage 'Connected'
      @formatter.setFromUs true

    privmsg: (from, msg) ->
      nick = @win.conn.irc.nick
      nickMentioned = not @_isOwnNick(from) and
        chat.NickMentionedNotification.shouldNotify(nick, msg)
      @_handleNotifications from, msg, nickMentioned

      @formatter.setMessage '#content'
      @formatter.addStyle 'mention' if nickMentioned
      @formatter.setPrettyFormat false
      if m = @_getUserAction msg
        @formatter.setContent "#{from} #{m[1]}"
        @formatter.addStyle 'action'
      else
        @source = from
        @formatter.setContent msg

    error: (msg) ->
      @formatter.setStyle 'notice'
      @formatter.setContent msg
      @formatter.setMessage '#content'

  _getMode: (mode) ->
    # TODO handle other modes besides just +o
    switch mode
      when '+o' then 'channel operator'
      else mode

  _getUserAction: (msg) ->
    /^\u0001ACTION (.*)\u0001/.exec msg

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
