exports = window


class AutoComplete
  ##
  # Inserted after a nick which is at the start of the input is auto-completed.
  # @const
  ##
  @COMPLETION_SUFFIX = ':'

  constructor: ->
    @_completionFinder = new CompletionFinder

  ##
  # Set the context from which the list of nicks can be generated.
  # @param {Object} context
  ##
  setContext: (context) ->
    @_context = context
    @_completionFinder.setCompletionGenerator @_getPossibleCompletions

  ##
  # Returns a list of nicks in the current channel.
  # @return {Array<string>}
  ##
  _getPossibleCompletions: =>
    chan = @_context.currentWindow.target
    nicks = @_context.currentWindow.conn?.irc.channels[chan]?.names
    if nicks?
      ownNick = @_context.currentWindow.conn.irc.nick
      return (nick for norm, nick of nicks when nick isnt ownNick)
    return []

  ##
  # Returns the passed in text, with the current stub replaced with its
  # completion.
  # @param {string} text The text the user has input.
  # @param {number} cursor The current position of the cursor.
  ##
  getTextWithCompletion: (text, cursor) ->
    @_text = text
    @_cursor = cursor
    if @_previousText isnt @_text
      @_completionFinder.reset()
    @_previousCursor = @_cursor
    unless @_completionFinder.hasStarted
      @_extractStub()
    textWithCompletion = @_preCompletion + @_getCompletion() + @_postCompletion
    @_previousText = textWithCompletion
    textWithCompletion

  ##
  # Returns the completion for the current stub with the completion suffix and/
  # or space after.
  ##
  _getCompletion: ->
    completion = @_completionFinder.getCompletion @_stub
    return @_stub if completion is @_stub
    if @_preCompletion.length is 0
      completion += AutoComplete.COMPLETION_SUFFIX
    completion += ' '

  ##
  # Finds the stub by looking at the cursor position, then finds the text before
  # and after the stub.
  ##
  _extractStub: ->
    stubEnd = @_findNearest @_cursor - 1, /\S/
    if stubEnd < 0 then stubEnd = 0
    preStubEnd = @_findNearest stubEnd, /\s/
    @_preCompletion = @_text.slice 0, preStubEnd+1
    @_stub = @_text[preStubEnd+1..stubEnd]
    @_postCompletion = @_text[stubEnd+1..]

  ##
  # Searches backwards until the regex matches the current character.
  # @return {number} The position of the matched character or -1 if not found.
  ##
  _findNearest: (start, regex) ->
    for i in [start..0]
      return i if regex.test @_text[i]
    -1

exports.AutoComplete = AutoComplete