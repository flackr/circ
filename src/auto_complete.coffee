exports = window

class AutoComplete
  constructor: (opt_getCompletionsCallback) ->
    @_completions = []
    @_getCompletions = opt_getCompletionsCallback
    @reset()

  clearCompletions: () ->
    @_completions = []

  addCompletions: (completions) ->
    @_completions = @_completions.concat completions

  setCompletions: (completions) ->
    @clearCompletions()
    @addCompletions completions

  getCompletion: (opt_stub) ->
    unless @hasStarted
      @_buildCompletions()
      @_currentStub = opt_stub
      @_findCompletions()
      @hasStarted = true
    @_getNextCompletion()

  _buildCompletions: ->
    if @_getCompletions?
      @setCompletions @_getCompletions()

  _findCompletions: ->
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
    @_currentCompletions = []
    @_completionIndex = 0
    @currentStub = ''
    @hasStarted = false

exports.AutoComplete = AutoComplete