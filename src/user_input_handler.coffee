exports = window

class UserInputHandler extends EventEmitter
  @ENTER_KEY = 13

  constructor: (@input, @window) ->
    super
    @input.focus()
    @input.keydown @_handleKeydown
    @window.keydown @_handleGlobalKeydown

  setContext: (@context) ->

  _handleGlobalKeydown: (e) =>
    unless e.metaKey or e.ctrlKey
      e.currentTarget = @input[0]
      @input.focus()
    if e.altKey and 48 <= e.which <= 57
      @emit 'switch_window', e.which - 48
      e.preventDefault()

  _handleKeydown: (e) =>
    if e.which == UserInputHandler.ENTER_KEY
      text = @input.val()
      if text.length > 0
        @input.val('')
        @_handleTextInput text

  _handleTextInput: (text) =>
    words = text.split(/\s+/)
    if text[0] == '/'
      name = words[0][1..].toLowerCase()
      text = words[1..]
    else
      name = 'say'
      text = words
    server = @context.currentWindow.conn?.name
    channel = @context.currentWindow.target
    event = new Event 'command', name, text...
    event.setContext server, channel
    @emit event.type, event

exports.UserInputHandler = UserInputHandler