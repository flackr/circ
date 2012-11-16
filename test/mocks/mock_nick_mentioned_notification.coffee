exports = window.mocks ?= {}

class NickMentionedNotification extends window.chat.NickMentionedNotification

  @useMock: ->
    window.chat.NickMentionedNotification = NickMentionedNotification
    chrome.app.window =
      current: -> { drawAttention: (->), focus: (->) }

  @notificationCount: 0

  constructor: ->
    super

  _createNotification: ->
    @notification =
      show: -> NickMentionedNotification.notificationCount++
      cancel: ->

exports.NickMentionedNotification = NickMentionedNotification