exports = window

class AutoComplete
  constructor: (opt_getCompletionsCallback) ->
    @_completions = []
    @_getCompletions = opt_getCompletionsCallback

    @_currentCompletions = []
    @_currentStub = undefined
    @_completionIndex = 0

  clearCompletions: () ->
    @_completions = []

  addCompletions: (completions) ->
    @_completions = @_completions.concat completions

  setCompletions: (completions) ->
    @clearCompletions()
    @addCompletions completions

  getCompletion: (opt_stub) ->
    unless @_currentStub
      @_buildCompletions()
      @_currentStub = opt_stub
      @_findCompletions()
    @_getNextCompletion()

  _buildCompletions: ->
    if @_getCompletions?
      @setCompletions @_getCompletions()

  _findCompletions: ->
    @_currentCompletions = []
    @_completionIndex = 0
    ignoreCase = not /[A-Z]/.test @_currentStub
    for completion in @_completions
      candidate = if ignoreCase then completion.toLowerCase() else completion
      if candidate.indexOf(@_currentStub) is 0
        @_currentCompletions.push completion

  _getNextCompletion: ->
    return @_currentStub if @_currentCompletions.length is 0
    result = @_currentCompletions[@_completionIndex]
    @_completionIndex++
    if @_completionIndex >= @_currentCompletions.length
      @_completionIndex = 0
    result

  reset: ->
    @_currentStub = undefined

exports.AutoComplete = AutoComplete