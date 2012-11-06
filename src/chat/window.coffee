exports = window.chat ?= {}

##
# A window for a specific IRC channel.
##
class Window extends EventEmitter

  ##
  # The screen will auto scroll as long as the user didn't scroll up more then
  # this many pixels.
  ##
  @SCROLLED_DOWN_BUFFER = 8

  constructor: (server, opt_channel) ->
    super
    @name = server + if opt_channel then " #{opt_channel}" else ''
    @wasScrolledDown = true
    @messageRenderer = new chat.window.MessageRenderer this
    @_addUI()
    @notifications = []
    @_isVisible = false
    @_isFocused = false
    $(window).focus @_onFocus
    $(window).blur @_onBlur

  clearNotifications: ->
    for notification in @notifications
      notification.cancel()

  _onFocus: =>
    return unless @_isVisible
    @_isFocused = true
    @clearNotifications()
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
    @$messagesContainer = $ '#messages-container'
    @$messages = $('#templates .messages').clone()

  _addNickUI: ->
    @$nicksContainer = $ '#nicks-container'
    @$nicks = $('#templates .nicks').clone()
    @nicks = new chat.NickList @$nicks

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
    @scroll = @$messagesContainer.scrollTop()
    @wasScrolledDown = @isScrolledDown()
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
    @$roomsAndNicks.removeClass 'no-nicks' if @target?
    @$messagesContainer.append @$messages
    @$nicksContainer.append @$nicks
    if @wasScrolledDown
      @scroll = @_getScrollHeight()
    @$messagesContainer.scrollTop @scroll

  isScrolledDown: ->
    scrollPosition = @$messagesContainer.scrollTop() + @$messagesContainer.height()
    scrollPosition >= @_getScrollHeight() - Window.SCROLLED_DOWN_BUFFER

  _getScrollHeight: ->
    @$messagesContainer[0].scrollHeight

  message: (from, msg, style...) ->
    wasScrolledDown = @isScrolledDown()
    @messageRenderer.message from, msg, style...
    if wasScrolledDown
      @scrollToBottom()

  scrollToBottom: ->
    @$messagesContainer.scrollTop @_getScrollHeight()

exports.Window = Window