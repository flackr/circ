exports = window.mocks ?= {}

class NickMentionedNotification extends window.chat.NickMentionedNotification

  @use: ->
    window.chat.NickMentionedNotification = NickMentionedNotification

  @notificationCount: 0

  constructor: ->
    super

  _createNotification: ->
    @notification =
      show: -> NickMentionedNotification.notificationCount++
      cancel: ->

exports.NickMentionedNotification = NickMentionedNotification