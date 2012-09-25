exports = window

class InputStack

  constructor: (showInputCallback, getCurrentTextCallback) ->
    @_showInput = showInputCallback
    @_getCurrentText = getCurrentTextCallback
    @_previousInputs = ['']
    @_previousInputIndex = 0

  showPreviousInput: ->
    if @_previousInputIndex == 0
      @_previousInputs[0] = @_getCurrentText()
    unless @_previousInputIndex >= @_previousInputs.length - 1
      @_previousInputIndex++
      @_showInput @_previousInputs[@_previousInputIndex]

  showNextInput: ->
    unless @_previousInputIndex <= 0
      @_previousInputIndex--
      @_showInput @_previousInputs[@_previousInputIndex]

  reset: ->
    @_previousInputIndex = 0

  addInput: (input) ->
    @_previousInputs.splice 1, 0, input

exports.InputStack = InputStack