exports = window.chat ?= {}

##
# A wrapper around a webkit notification. Used to display desktop notifications.
##
class Notification extends EventEmitter

  # The default image to display on notifications
  @defaultImage: 'http://sourceforge.net/p/acupofjavachat/icon'

  constructor: (@_title, @_message, @_image=Notification.defaultImage) ->
    super
    @_createNotification()
    @_addOnClickListener()
    Notification.windowMap

  _createNotification: ->
    @notification = webkitNotifications.createNotification @_image, @_title,
        @_message

  _addOnClickListener: ->
    @notification.onclick = =>
      @cancel()
      @emit 'clicked'

  delete: ->
    @notification.onclick = null
    delete @notification

  ##
  # Display the notification.
  ##
  show: ->
    @notification.show()

  ##
  # Close the notification.
  ##
  cancel: ->
    @notification.cancel()

  ##
  # Used as a hash function for notifications.
  ##
  toString: ->
    @_title + @_message


exports.Notification = Notification