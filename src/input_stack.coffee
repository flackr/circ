exports = window

##
# A traversable stack of all input entered by the user.
##
class InputStack

  constructor: ->
    @_previousInputs = ['']
    @_previousInputIndex = 0

  ##
  # Keeps track of the unentered input that was present when the user
  # began traversing the stack.
  # @param {string} text
  ##
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

  ##
  # Restarts the traversal position. Should be called when the user begins
  # typing a new command.
  ##
  reset: ->
    @_previousInputIndex = 0

  ##
  # Add input to the stack.
  # @param {string} input
  ##
  addInput: (input) ->
    @_previousInputs.splice 1, 0, input

exports.InputStack = InputStack