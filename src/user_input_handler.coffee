exports = window

class UserInputHandler extends EventEmitter
  @ENTER_KEY = 13
  @UP = 38
  @DOWN = 40
  @TAB = 9

  constructor: (@input, @window) ->
    super
    @input.focus()
    @inputStack = new InputStack
    @autoComplete = new AutoComplete @_getCompletions
    @input.keydown @_handleKeydown
    @window.keydown @_handleGlobalKeydown

  _getCompletions: =>
    chan = @context.currentWindow.target
    nicks = @context.currentWindow.conn?.irc.channels[chan]?.names
    if nicks?
      ownNick = @context.currentWindow.conn.irc.nick
      return (nick for norm, nick of nicks when nick isnt ownNick)
    return []

  setContext: (@context) ->

  _handleGlobalKeydown: (e) =>
    @text = @input.val()
    @_handleFocusingInput e
    @_handleSwitchingWindows e
    @_handleShowingPreviousCommands e
    @_handleAutoComplete e
    true

  _handleFocusingInput: (e) ->
    unless e.metaKey or e.ctrlKey
      e.currentTarget = @input[0]
      @input.focus()

  _handleSwitchingWindows: (e) ->
    if e.altKey and 48 <= e.which <= 57
      @emit 'switch_window', e.which - 48
      e.preventDefault()

  _handleShowingPreviousCommands: (e) ->
    if e.which == UserInputHandler.UP or e.which == UserInputHandler.DOWN
      e.preventDefault()
      if e.which == UserInputHandler.UP
        @inputStack.setCurrentText @text
        input = @inputStack.showPreviousInput()
      else
        input = @inputStack.showNextInput()
      @input.val(input) if input?
    else
      @inputStack.reset()

  _handleAutoComplete: (e) ->
    if e.which == UserInputHandler.TAB
      e.preventDefault()
      if @text
        @_suggestCompletion()
    else
      @autoComplete.reset()

  _suggestCompletion: ->
    if @autoComplete.hasStarted and @_cursorMoved
      @autoComplete.reset()
    unless @autoComplete.hasStarted
      @_extractStub()
    @_showCompletion()

  _showCompletion: ->
    completion = @autoComplete.getCompletion @stub
    @input.val @preCompletion + completion + @postCompletion

  _handleKeydown: (e) =>
    @text = @input.val()
    if e.which == UserInputHandler.ENTER_KEY
      if @text.length > 0
        @input.val('')
        @_sendUserCommand()
    true

  _sendUserCommand: =>
    @inputStack.addInput @text
    words = @text.split(/\s+/)
    if @text[0] == '/'
      name = words[0][1..].toLowerCase()
      words = words[1..]
    else
      name = 'say'
    server = @context.currentWindow.conn?.name
    channel = @context.currentWindow.target
    event = new Event 'command', name, words...
    event.setContext server, channel
    @emit event.type, event

  ##
  # Finds the stub by looking at the cursor position, then finds the text before
  # and after the stub.
  ##
  _extractStub: ->
    stubEnd = @_findNearest @_getCursorPosition() - 1, /\S/
    if stubEnd < 0 then stubEnd = 0
    preStubEnd = @_findNearest stubEnd, /\s/
    @preCompletion = @text.slice 0, preStubEnd+1
    @stub = @text[preStubEnd+1..stubEnd]
    @postCompletion = @text[stubEnd+1..]

  ##
  # Searches backwards until the regex matches the current character.
  # @return {number} The position of the matched character or -1 if not found.
  ##
  _findNearest: (start, regex) ->
    for i in [start..0]
      return i if regex.test @text[i]
    -1

  _getCursorPosition: ->
    @input[0].selectionStart

exports.UserInputHandler = UserInputHandler