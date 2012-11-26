exports = window

##
# Takes a string and replaces a word with its completion based on the cursor position.
# Currently only supports completion of nicks in the current window.
##
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
  # @param {{currentWindow: {target: string, conn: Object}}} context
  ##
  setContext: (context) ->
    @_context = context
    @_completionFinder.setCompletionGenerator @_getPossibleCompletions

  ##
  # Returns a list of possible auto-completions in the current channel.
  # @return {Array.<Completion>}
  ##
  _getPossibleCompletions: =>
    completions = []
    completions = completions.concat @_getCommandCompletions()
    completions = completions.concat @_getNickCompletions()
    return completions

  ##
  # Returns a list of commands.
  # @return {Array.<Completion>}
  ##
  _getCommandCompletions: ->
    commands = @_context.userCommands.getCommands()
    commandNames = (commandName for commandName, commandObj of commands)
    commandNames.sort()
    (new Completion(cmd, Completion.CMD) for cmd in commandNames)

  ##
  # Returns a list of nicks in the current channel.
  # @return {Array.<Completion>}
  ##
  _getNickCompletions: ->
    chan = @_context.currentWindow.target
    nicks = @_context.currentWindow.conn?.irc.channels[chan]?.names
    if nicks?
      ownNick = @_context.currentWindow.conn.irc.nick
      completions = []
      for norm, nick of nicks when nick isnt ownNick
        completions.push new Completion(nick, Completion.NICK)
      return completions
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
    completion = @_getCompletion()
    textWithCompletion = @_preCompletion + completion + @_postCompletion
    @_updatedCursorPosition = @_preCompletion.length + completion.length
    @_previousText = textWithCompletion
    textWithCompletion

  getUpdatedCursorPosition: ->
    @_updatedCursorPosition ? 0

  ##
  # Returns the completion for the current stub with the completion suffix and
  # or space after.
  ##
  _getCompletion: ->
    completion = @_completionFinder.getCompletion @_stub
    return @_stub if completion is CompletionFinder.NONE
    return completion.getText() + completion.getSuffix(@_preCompletion.length)

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

  ##
  # Simple storage class for completions which stores the completion text
  # and type of completion.
  ##
  class Completion

    ##
    # Completions can either be commands or nicks.
    ##
    @CMD = 0
    @NICK = 1

    @COMPLETION_SUFFIX = ':'

    constructor: (@_text, @_type) ->
      if @_type is Completion.CMD
        @_text = '/' + @_text

    getText: ->
      return @_text

    getType: ->
      return @_type

    getSuffix: (preCompletionLength) ->
      if @_type is Completion.NICK and preCompletionLength is 0
        return Completion.COMPLETION_SUFFIX + ' '
      return ' '

    toString: ->
      return @getText()

exports.AutoComplete = AutoComplete
