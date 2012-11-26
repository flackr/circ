exports = window.chat ?= {}

class NotificationGroup extends EventEmitter

  constructor: (opt_channel) ->
    super
    @_channel = opt_channel
    @_size = 0
    @_notification = null
    @_stubs = []

  add: (item) ->
    @_notification?.cancel()
    @_size++
    @_createNotification item
    @_notification.show()

  _createNotification: (item) ->
    @_addStubIfUnique item.getStub()
    if @_size is 1
      title = item.getTitle()
      body = item.getBody()
    else
      if @_channel
        title = "#{@_size} notifications in #{@_channel}"
      else
        title = "#{@_size} notifications"
      body = @_stubs.join ', '
    body = truncateIfTooLarge body, 75
    @_notification = new chat.Notification title, body
    @_addNotificationListeners()

  _addStubIfUnique: (stub) ->
    unless stub in @_stubs
      @_stubs.push stub


  _addNotificationListeners: ->
    @_notification.on 'clicked', =>
      @emit 'clicked'
    @_notification.on 'close', =>
      @_clear()

  clear: ->
    @_notification?.cancel()
    @_size = 0
    @_stubs = []

exports.NotificationGroup = NotificationGroup