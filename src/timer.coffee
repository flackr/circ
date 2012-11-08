exports = window

##
# Utility class for determining the time between events.
##
class Timer

  # Maps events to their timing information.
  _events: {}

  ##
  # Mark the start time of an event.
  # @param {string} name The name of the event.
  ##
  start: (name) ->
    @_events[name] = { startTime: @_getCurrentTime() }

  ##
  # Destroy the event and return the elapsed time.
  # @param {string} name The name of the event.
  ##
  finish: (name) ->
    time = @elapsed name
    delete @_events[name]
    return time

  ##
  # Returns the elapsed time..
  # @param {string} name The name of the event.
  ##
  elapsed: (name) ->
    return 0 unless @_events[name]
    @_getCurrentTime() - @_events[name].startTime

  _getCurrentTime: ->
    new Date().getTime()

exports.Timer = Timer