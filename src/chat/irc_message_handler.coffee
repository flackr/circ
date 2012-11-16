exports = window.chat ?= {}

##
# Handles messages to be displayed in a window.
##
class IRCMessageHandler extends MessageHandler

  constructor: (@_chat) ->
    @_formatter = new window.chat.MessageFormatter
    @_chatLog = new chat.ChatLog
    @_chatLog.whitelist 'privmsg' # only log private messages
    super

  getChatLog: ->
    @_chatLog.getData()

  logMessagesFromWindow: (win) ->
    win.on 'message', @_chatLog.add

  ##
  # Replays the given chatlog so the user can see the conversation they
  # missed.
  ##
  replayChatLog: (opt_chatLogData) ->
    @_chatLog.loadData opt_chatLogData if opt_chatLogData
    for context in @_chatLog.getContextList()
      win = @_chat.winList.get context.server, context.channel
      continue unless win
      win.rawMessage @_chatLog.get context

  setWindow: (@_win) ->
    @_formatter.setNick @_win.conn?.irc.nick

  setCustomMessageStyle: (customStyle) ->
    @_formatter.setCustomStyle customStyle

  handle: (type, params...) ->
    @_setDefaultValues params
    super type, params...
    @_sendFormattedMessage()

  _setDefaultValues: (params) ->
    @source = ''
    @_formatter.clear()
    @_formatter.setContext params...

  _handlers:
    topic: (from, topic) ->
      @_chat.updateStatus()
      @_formatter.setContent topic
      if not topic
        @_formatter.addStyle 'notice'
        @_formatter.setMessage 'no topic is set'
      else if not from
        @_formatter.addStyle 'notice'
        @_formatter.setMessage 'the topic is: #content'
      else
        @_formatter.addStyle 'update'
        @_formatter.setMessage '#from changed the topic to: #content'

    join: (nick) ->
      @_formatter.addStyle 'update'
      @_formatter.setMessage '#from joined the channel'
      @_win.nicks.add nick

    part: (nick) ->
      @_formatter.addStyle 'update'
      @_formatter.setMessage '#from left the channel'
      @_win.nicks.remove nick

    kick: (from, to, reason) ->
      @_formatter.addStyle 'update'
      @_formatter.setMessage '#from kicked #to from the channel: #content'
      @_win.nicks.remove to

    nick: (from, to) ->
      if @_isOwnNick to
        @_chat.updateStatus()
        @_formatter.setFromUs true
        @_formatter.setToUs false
      @_formatter.addStyle 'update'
      @_formatter.setMessage '#from is now known as #to'
      if not @_win.isServerWindow()
        @_win.nicks.remove from
        @_win.nicks.add to

    mode: (from, to, mode) ->
      return unless to
      @_formatter.addStyle 'update'
      @_formatter.setContent @_getModeMessage mode
      @_formatter.setMessage '#from #content #to'

    quit: (nick, reason) ->
      @_formatter.addStyle 'update'
      @_formatter.setMessage '#from has quit: #content'
      @_formatter.setContent reason
      @_win.nicks.remove nick

    disconnect: ->
      @_formatter.addStyle 'update'
      @_formatter.setMessage 'Disconnected'
      @_formatter.setFromUs true

    connect: ->
      @_formatter.addStyle 'update'
      @_formatter.setMessage 'Connected'
      @_formatter.setFromUs true

    privmsg: (from, msg) ->
      @_formatter.addStyle 'update'
      @_handleMention from, msg
      @_formatPrivateMessage from, msg

    breakgroup: (msg='') ->
      @_formatter.setContentMessage msg

    error: (msg) ->
      @_formatter.setContentMessage msg

    system_notice: (msg) ->
      @_formatter.setContentMessage msg

    notice: (msg) ->
      @_formatter.addStyle 'notice-group'
      @_formatter.setContentMessage msg

    welcome: (msg) ->
      @_formatter.addStyle 'group'
      @_formatter.setContentMessage msg

    ##
    # Generic messages - usually boring server stuff like MOTD.
    ##
    other: (cmd) ->
      @_formatter.addStyle 'group'
      @_formatter.setContentMessage cmd.params[cmd.params.length - 1]

    nickinuse: (taken, wanted) ->
      @_formatter.addStyle 'notice'
      msg = "Nickname #{taken} already in use."
      if wanted
        msg += " Trying to get nickname #{wanted}."
      @_formatter.setMessage msg

    away: (msg) ->
      @_chat.updateStatus()
      @_formatter.addStyle 'notice'
      @_formatter.setContentMessage msg

  _getModeMessage: (mode) ->
    pre = if mode[0] is '+' then 'gave' else 'took'
    post = if mode[0] is '+' then 'to' else 'from'
    mode = @_getMode mode
    "#{pre} #{mode} #{post}"

  _getMode: (mode) ->
    switch mode[1]
      when 'o' then 'channel operator status'
      when 'O' then 'local operator status'
      when 'v' then 'voice'
      when 'i' then 'invisible status'
      when 'w' then 'wall operator status'
      when 'a' then 'away status'
      else mode

  _getUserAction: (msg) ->
    /^\u0001ACTION (.*)\u0001/.exec msg

  _handleMention: (from, msg) ->
    nickMentioned = @_nickWasMentioned from, msg
    @_formatter.addStyle 'mention' if nickMentioned and not @_win.isPrivate()
    if nickMentioned and @_shouldNotifyMention()
      @_createNotification from, msg
    unless @_isFromWindowInFocus()
      @_chat.channelDisplay.activity @_win.conn?.name, @_win.target
      if nickMentioned
        @_chat.channelDisplay.mention @_win.conn?.name, @_win.target

  _createNotification: (from, msg) ->
    notification = new chat.NickMentionedNotification @_win.target, from, msg
    notification.show()
    @_win.notifications.push notification
    win = @_win
    notification.on 'clicked', =>
      removeFromArray win.notifications, notification
      @_chat.switchToWindow win
      chrome.app.window.current().focus()

  _nickWasMentioned: (from, msg) ->
    nick = @_win.conn?.irc.nick
    return false if @_isOwnNick from
    return false if @_formatter.hasStyle 'notice'
    return false if @_formatter.hasStyle 'direct'
    return true if @_win.isPrivate()
    return chat.NickMentionedNotification.shouldNotify nick, msg

  _shouldNotifyMention: () ->
    not @_isFromWindowInFocus() or not window.document.hasFocus()

  _isFromWindowInFocus: ->
    @_win.equals @_chat.currentWindow

  _formatPrivateMessage: (from, msg) ->
    @_formatter.setMessage '#content'
    @_formatter.setPrettyFormat false
    if m = @_getUserAction msg
      @_formatter.setContent "#{from} #{m[1]}"
      @_formatter.addStyle 'action'
    else
      if @_formatter.hasStyle 'notice'
        @source = "-#{from}-"
      else if @_formatter.hasStyle 'direct'
        @source = ">#{from}<"
      else
        @source = from
      @_formatter.setContent msg

  _sendFormattedMessage: ->
    return unless @_formatter.hasMessage()
    @_formatter.addStyle @type
    @_win.message @source, @_formatter.format(), @_formatter.getStyle()

  _isOwnNick: (nick) ->
    @_win.conn?.irc.isOwnNick nick

exports.IRCMessageHandler = IRCMessageHandler
