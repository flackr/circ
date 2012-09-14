exports = window

class UserInputHandler extends EventEmitter
  @ENTER_KEY = 13

  constructor: ->
    super
    @$cmd = $('#cmd')
    @$cmd.focus()
    @$cmd.keydown @_handleKeydown
    @$window = $(window)
    @$window.keydown @_handleGlobalKeydown

  setContext: (@context) ->

  _handleGlobalKeydown: (e) =>
    unless e.metaKey or e.ctrlKey
      e.currentTarget = @$cmd[0]
      @$cmd.focus()
    if e.altKey and 48 <= e.which <= 57
      @emit 'switch_window', e.which - 48
      e.preventDefault()

  _handleKeydown: (e) =>
    if e.which == UserInputHandler.ENTER_KEY
      input = @$cmd.val()
      if input.length > 0
        @$cmd.val('')
        @_handleTextInput input

  _handleTextInput: (text) =>
    type = 'say'
    if text[0] == '/'
      words = text[1..].split(/\s+/)
      type = words[0].toLowerCase()
      text = if words.length > 1 then words[1..] else undefined
    server = @context.currentWindow.conn?.name
    channel = @context.currentWindow.target
    @emit 'command', server, channel, type, text

exports.UserInputHandler = UserInputHandler