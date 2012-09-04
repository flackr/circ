exports = window.chat ?= {}

class Notification extends EventEmitter
  @default_image: 'icon/icon48.png'

  constructor: (@_title, @_message, @_image=@default_image) ->
    @notification = webkitNotifications.createNotification(
      @_image, @_title, @_message)

    @notification.onclick = (=> @emit 'clicked')

  show: ->
    @notification.show()

  cancel: ->
    @notification.cancel()

exports.Notification = Notification