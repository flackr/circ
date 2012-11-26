exports = window

##
# Finds completions for a partial word.
# Completion candidates can be set using setCompletions() or by specifying a
# completion generator function.
##
class CompletionFinder

  ##
  # Returned when no completion was found.
  ##
  @NONE: undefined

  ##
  # Create a new completion finder and optionally set a callback that can be
  # used to retrieve completion candidates.
  # @param {function():Array<string>} opt_getCompletionsCallback
  ##
  constructor: (opt_getCompletionsCallback) ->
    @_completions = []
    @_getCompletions = opt_getCompletionsCallback
    @reset()

  ##
  # Set a callback that can be used to retrieve completion candidates.
  # @param {function():Array<string>} completionGenerator
  ##
  setCompletionGenerator: (completionGenerator) ->
    @_getCompletions = completionGenerator

  ##
  # Clear stored completion candidates.
  ##
  clearCompletions: () ->
    @_completions = []

  ##
  # Add completion candidates.
  # @param {Array<string>} completions
  ##
  addCompletions: (completions) ->
    @_completions = @_completions.concat completions

  setCompletions: (completions) ->
    @clearCompletions()
    @addCompletions completions

  ##
  # Get a completion for the current stub.
  # The stub only needs to be passed in the first time getCompletion() is
  # called or after reset() is called.
  # @param {string} opt_stub The partial word to auto-complete.
  ##
  getCompletion: (opt_stub) ->
    unless @hasStarted
      @_generateCompletions()
      @_currentStub = opt_stub
      @_findCompletions()
      @hasStarted = true
    @_getNextCompletion()

  ##
  # Add completions from the completion generator, if set.
  ##
  _generateCompletions: ->
    if @_getCompletions?
      @setCompletions @_getCompletions()

  ##
  # Create a list of all possible completions for the current stub.
  ##
  _findCompletions: ->
    ignoreCase = not /[A-Z]/.test @_currentStub
    for completion in @_completions
      completionText = completion.toString()
      candidate = if ignoreCase then completionText.toLowerCase() else completionText
      if candidate.indexOf(@_currentStub) is 0
        @_currentCompletions.push completion

  ##
  # Get the next completion, or NONE if no completions are found.
  # Completions are returned by iterating through the list of possible
  # completions.
  # @returns {string|NONE}
  ##
  _getNextCompletion: ->
    return CompletionFinder.NONE if @_currentCompletions.length is 0
    result = @_currentCompletions[@_completionIndex]
    @_completionIndex++
    if @_completionIndex >= @_currentCompletions.length
      @_completionIndex = 0
    result

  ##
  # Reset the current stub and clear the list of possible completions.
  # The current stub will be set again the next time getCompletion() is called.
  ##
  reset: ->
    @_currentCompletions = []
    @_completionIndex = 0
    @currentStub = ''
    @hasStarted = false

exports.CompletionFinder = CompletionFinder
