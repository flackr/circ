exports = window

##
# Utility class for determining the time between events.
##
class Timer

  # Maps events to their timing information.
  _events: {}

  ##
  # Mark the start time of an event.
  # @param {Class} namespace The namespace for which this event blongs
  # @param {string} name The name of the event.
  ##
  start: (namespace, name) ->
    @_add namespace, name

  ##
  # Mark the start time of an event.
  # @param {Object} namespace The namespace for which this event blongs
  # @param {string} name The name of the event.
  ##
  finish: (namespace, name) ->
    event = @_get namespace, name
    time = @_getCurrentTime() - event.startTime
    @_delete namespace, name
    return time

  ##
  # Creates a hash of the namespace and name to uniquely identify the event.
  ##
  _hash: (namespace, name) ->
    namespace = namespace.constructor.name
    return namespace.constructor.name + name

  _getCurrentTime: ->
    new Date().getTime()

  _add: (namespace, name) ->
    hash = @_hash namespace, name
    @_events[hash] =
      startTime: @_getCurrentTime()

  _get: (namespace, name) ->
    hash = @_hash namespace, name
    @_events[hash]

  _delete: (namespace, name) ->
    hash = @_hash namespace, name
    delete @_events[hash]

exports.timer = new Timer