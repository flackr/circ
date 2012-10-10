exports = window.chat ?= {}

class Notification extends EventEmitter
  @defaultImage: 'http://sourceforge.net/p/acupofjavachat/icon'

  constructor: (@_title, @_message, @_image=Notification.defaultImage) ->
    super
    @_createNotification()
    @_addOnClickListener()

  _createNotification: ->
    @notification = webkitNotifications.createNotification(
      @_image, @_title, @_message)

  _addOnClickListener: ->
    @notification.onclick = =>
      @cancel()
      @emit 'clicked'

  show: ->
    @notification.show()

  cancel: ->
    @notification.cancel()

exports.Notification = Notification