exports = window.mocks ?= {}

class Notification

  @useMock: ->
    webkitNotifications.createNotification = -> new Notification()
    chrome.app.window =
      current: -> { drawAttention: (->), focus: (->) }
    @numActive = 0

  constructor: ->

  show: ->
    Notification.numActive++

  cancel: ->
    Notification.numActive--
    @onclose?()

  click: ->
    @onclick?()

exports.Notification = Notification