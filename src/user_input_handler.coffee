exports = window

class UserInputHandler extends EventEmitter
  @ENTER_KEY = 13
  @UP = 38
  @DOWN = 40
  @TAB = 9

  constructor: (@input, @window) ->
    super
    @input.focus()
    @_inputStack = new InputStack
    @_autoComplete = new AutoComplete
    @input.keydown @_handleKeydown
    @window.keydown @_handleGlobalKeydown

  setContext: (@_context) ->
    @_autoComplete.setContext @_context

  _handleGlobalKeydown: (e) =>
    @text = @input.val()
    @_focusInputOnKeyPress e
    @_switchWindowsOnAltNumber e
    @_showPreviousCommandsOnArrowKeys e
    @_autoCompleteOnTab e
    e.defaultPrevented

  _focusInputOnKeyPress: (e) ->
    unless e.metaKey or e.ctrlKey
      e.currentTarget = @input[0]
      @input.focus()

  _switchWindowsOnAltNumber: (e) ->
    if e.altKey and 48 <= e.which <= 57
      @emit 'switch_window', e.which - 48
      e.preventDefault()

  _showPreviousCommandsOnArrowKeys: (e) ->
    if e.which == UserInputHandler.UP or e.which == UserInputHandler.DOWN
      e.preventDefault()
      if e.which == UserInputHandler.UP
        @_inputStack.setCurrentText @text
        input = @_inputStack.showPreviousInput()
      else
        input = @_inputStack.showNextInput()
      @input.val(input) if input?
    else
      @_inputStack.reset()

  _autoCompleteOnTab: (e) ->
    if e.which == UserInputHandler.TAB
      e.preventDefault()
      if @text
        @input.val @_autoComplete.getTextWithCompletion @text, @_getCursorPosition()

  _getCursorPosition: ->
    @input[0].selectionStart

  _handleKeydown: (e) =>
    @text = @input.val()
    if e.which == UserInputHandler.ENTER_KEY
      if @text.length > 0
        @input.val('')
        @_sendUserCommand()
    true

  _sendUserCommand: =>
    @_inputStack.addInput @text
    words = @text.split(/\s/)
    if @text[0] == '/'
      name = words[0][1..].toLowerCase()
      words = words[1..]
    else
      name = 'say'
    server = @_context.currentWindow.conn?.name
    channel = @_context.currentWindow.target
    event = new Event 'command', name, words...
    event.setContext server, channel
    @emit event.type, event

exports.UserInputHandler = UserInputHandler