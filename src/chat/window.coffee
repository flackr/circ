exports = window.chat ?= {}

class Window
  ##
  # The screen will auto scroll as long as the user didn't scroll up more then
  # this many pixels.
  ##
  @SCROLLED_DOWN_BUFFER = 8

  constructor: (server, opt_channel) ->
    @name = server + if opt_channel then " #{opt_channel}" else ''
    @wasScrolledDown = true
    @$container = $ "<div id='window-container'>"
    @$messages = $ "<div id='chat-messages'>"
    @$chatDisplay = $ "<div id='chat-display'>"
    chatDisplayContainer = $ "<div id='chat-display-container'>"
    chatDisplayContainer.append @$chatDisplay
    @$chatDisplay.append @$messages
    @$container.append chatDisplayContainer
    @messageRenderer = new chat.window.MessageRenderer @$messages

  setTarget: (@target) ->
    @_addNickList() unless @isPrivate()

  isServerWindow: ->
    return not @target?

  equals: (win) ->
    return @name is win.name

  ##
  # Marks the window as private.
  # Private windows are used for direct messages from /msg.
  ##
  makePrivate: ->
    @$nickWrapper?.remove()
    @_private = true

  isPrivate: ->
    return @_private?

  _addNickList: ->
    nicks = $ "<ol id='nicks'>"
    nickDisplay = $ "<div id='nick-display'>"
    @$nickWrapper = $ "<div id='nick-display-container'>"
    nickDisplay.append nicks
    @$nickWrapper.append nickDisplay
    @$container.append @$nickWrapper
    @nicks = new chat.NickList(nicks)

  detach: ->
    @scroll = @$chatDisplay.scrollTop()
    @wasScrolledDown = @isScrolledDown()
    @$container.detach()

  remove: ->
    @$container.remove()

  attachTo: (container) ->
    container.prepend @$container
    if @wasScrolledDown
      @scroll = @$chatDisplay[0].scrollHeight
    @$chatDisplay.scrollTop(@scroll)

  isScrolledDown: ->
    scrollPosition = @$chatDisplay.scrollTop() + @$chatDisplay.height()
    scrollPosition >= @$chatDisplay[0].scrollHeight - Window.SCROLLED_DOWN_BUFFER

  displayHelp: (commands) ->
    @messageRenderer.displayHelp commands

  displayWelcome: ->
    @messageRenderer.displayWelcome()

  displayEmptyLine: ->
    @messageRenderer.displayEmptyLine()

  message: (from, msg, style...) ->
    wasScrolledDown = @isScrolledDown()
    @messageRenderer.message from, msg, style...
    if wasScrolledDown
      @scrollToBottom()

  scrollToBottom: ->
    @$chatDisplay.scrollTop(@$chatDisplay[0].scrollHeight)

exports.Window = Window