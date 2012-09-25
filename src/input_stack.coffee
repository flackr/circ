exports = window

class InputStack

  constructor: ->
    @_previousInputs = ['']
    @_previousInputIndex = 0

  setCurrentText: (text) ->
    if @_previousInputIndex == 0
      @_previousInputs[0] = text

  showPreviousInput: ->
    unless @_previousInputIndex >= @_previousInputs.length - 1
      @_previousInputIndex++
      return @_previousInputs[@_previousInputIndex]
    return undefined

  showNextInput: ->
    unless @_previousInputIndex <= 0
      @_previousInputIndex--
      return @_previousInputs[@_previousInputIndex]
    return undefined

  reset: ->
    @_previousInputIndex = 0

  addInput: (input) ->
    @_previousInputs.splice 1, 0, input

exports.InputStack = InputStack