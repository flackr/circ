exports = window

##
# Manages keyboard and hotkey input from the user, including autocomplete and
# traversing through previous commands.
##
class UserInputHandler extends EventEmitter

  constructor: (@input, @window) ->
    super
    @input.focus()
    @_inputStack = new InputStack
    @_autoComplete = new AutoComplete
    @_keyboardShortcutMap = new KeyboardShortcutMap()
    @input.keydown @_handleKeydown
    @window.keydown @_handleGlobalKeydown

  setContext: (@_context) ->
    @_autoComplete.setContext @_context
    @_context.on 'set_input', (text) =>
      @input.val text unless @input.val()

  _handleGlobalKeydown: (e) =>
    @text = @input.val()
    @_focusInputOnKeyPress e
    @_handleKeyboardShortcuts e
    return false if e.isDefaultPrevented()
    @_showPreviousCommandsOnArrowKeys e
    @_autoCompleteOnTab e
    !e.isDefaultPrevented()

  _focusInputOnKeyPress: (e) ->
    unless e.metaKey or e.ctrlKey
      e.currentTarget = @input[0]
      @input.focus()

  _handleKeyboardShortcuts: (e) ->
    [command, args] = @_keyboardShortcutMap.getMappedCommand e, @input.val()
    return unless command
    e.preventDefault()
    event = new Event 'command', command, args...
    @_emitEventToCurrentWindow event

  _showPreviousCommandsOnArrowKeys: (e) ->
    if e.which is keyCodes.toKeyCode('UP') or e.which is keyCodes.toKeyCode('DOWN')
      e.preventDefault()
      if e.which is keyCodes.toKeyCode('UP')
        @_inputStack.setCurrentText @text
        input = @_inputStack.showPreviousInput()
      else # pressed the down arrow key
        input = @_inputStack.showNextInput()
      @input.val(input) if input?
    else
      @_inputStack.reset()

  _autoCompleteOnTab: (e) ->
    if e.which == keyCodes.toKeyCode 'TAB'
      e.preventDefault()
      if @text
        textWithCompletion = @_autoComplete.getTextWithCompletion @text,
            @_getCursorPosition()
        @input.val textWithCompletion
        @_setCursorPosition @_autoComplete.getUpdatedCursorPosition()

  _setCursorPosition: (pos) ->
    @input[0].setSelectionRange pos, pos

  _getCursorPosition: ->
    @input[0].selectionStart

  _handleKeydown: (e) =>
    @text = @input.val()
    if e.which is keyCodes.toKeyCode 'ENTER'
      if @text.length > 0
        @input.val('')
        @_sendUserCommand()
    true

  ##
  # Wrap the input in an event and emit it.
  ##
  _sendUserCommand: =>
    @_inputStack.addInput @text
    words = @text.split(/\s/)
    if @text[0] == '/'
      name = words[0][1..].toLowerCase()
      words = words[1..]
    else
      name = 'say'
    event = new Event 'command', name, words...
    @_emitEventToCurrentWindow event

  _emitEventToCurrentWindow: (event) ->
    event.context = @_context.currentWindow.getContext()
    @emit event.type, event

exports.UserInputHandler = UserInputHandler