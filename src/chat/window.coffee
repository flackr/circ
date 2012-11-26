exports = window.chat ?= {}

##
# A window for a specific IRC channel.
##
class Window extends EventEmitter

  constructor: (server, opt_channel) ->
    super
    @name = server + if opt_channel then " #{opt_channel}" else ''
    @messageRenderer = new chat.window.MessageRenderer this
    @_addUI()
    @notifications = new chat.NotificationGroup opt_channel
    @_isVisible = false
    @_isFocused = false
    @_height = 0
    $(window).focus @_onFocus
    $(window).blur @_onBlur

  getContext: ->
    @_context ?= new Context @conn?.name, @target
    @_context

  _onFocus: =>
    return unless @_isVisible
    @_isFocused = true
    @notifications.clear()
    @messageRenderer.onFocus()

  _onBlur: =>
    @_isFocused = false

  isFocused: ->
    @_isFocused and @_isVisible

  _addUI: ->
    @_addMessageUI()
    @_addNickUI()
    @$roomsAndNicks = $ '#rooms-and-nicks'

  _addMessageUI: ->
    @$messagesContainer = new chat.Scrollable $ '#messages-container'
    @$messages = $('#templates .messages').clone()

  _addNickUI: ->
    @$nicksContainer = $ '#nicks-container'
    @$nicks = $('#templates .nicks').clone()
    @nicks = new chat.NickList @$nicks

  ##
  # Sets the window's channel.
  # @param {string} target
  ##
  setTarget: (@target) ->
    return if @isPrivate()
    @$roomsAndNicks.removeClass 'no-nicks'

  isServerWindow: ->
    !@target

  equals: (win) ->
    return @name is win.name

  ##
  # Marks the window as private.
  # Private windows are used for direct messages from /msg.
  ##
  makePrivate: ->
    @$roomsAndNicks.addClass 'no-nicks'
    @_private = true

  isPrivate: ->
    return @_private?

  detach: ->
    @$roomsAndNicks.addClass 'no-nicks'
    @$messages.detach()
    @$nicks.detach()
    @_isVisible = false

  remove: ->
    @detach()
    @$messages.remove()
    @$nicks.remove()

  attach: ->
    @_isVisible = true
    @_onFocus()
    if @target and not @isPrivate()
      @$roomsAndNicks.removeClass 'no-nicks'
    @$messagesContainer.append @$messages
    @$nicksContainer.append @$nicks
    @$messagesContainer.restoreScrollPosition()

  message: (from, msg, style...) ->
    @messageRenderer.message from, msg, style...

  ##
  # Append raw html to the message list.
  #
  # This is useful for adding a large number of messages quickly, such as
  # loading chat history.
  ##
  rawMessage: (html) ->
    @$messages.html @$messages.html() + html
    @$messagesContainer.restoreScrollPosition()

exports.Window = Window