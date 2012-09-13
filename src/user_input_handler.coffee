exports = window

class UserInputHandler extends EventEmitter
  @enterKey = 13

  constructor: ->
    @$cmd = $('#cmd')
    @$cmd.focus()
    @$cmd.keydown @_handleKeydown
    @$window = $(window)
    @$window.keydown @_handleGlobalKeydown

  setContext: (@context)

  _handleWindowKeydown: (e) =>
    unless e.metaKey or e.ctrlKey
      e.currentTarget = $('#cmd')[0]
      @$cmd.focus()
    if e.altKey and 48 <= e.which <= 57
      @emit 'switch_window', e.which - 48
      e.preventDefault()

  _handleKeydown: (e) =>
    if e.which == @enterKey
      input = @$cmd.val()
      if input.length > 0
        @$cmd.val('')
        @_handleTextInput input

  _handleTextInput: (text) =>
    type = 'say'
    if text[0] == '/'
      cmd = text[1..].split(/\s+/)
      type = cmd[0].toLowerCase()
      text = cmd[1..]
    server = context.currentWindow.conn.name
    channel = context.currentWindow.target
    @emit 'command', server, channel, cmd, text
