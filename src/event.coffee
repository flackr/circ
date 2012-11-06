exports = window

##
# A generic event often used in conjuction with emit().
##
class Event
  constructor: (@type, @name, @args...) ->

    # Info on which window the event took place in.
    @context = {}

    # Effects how the event is displayed.
    @style = []

    # Acts as an id for the event.
    @hook = @type + ' ' + @name

  setContext: (server, channel) ->
    @context = {server, channel}

  ##
  # Adds a custom style for the event that will effect how it's contents are
  # displayed.
  # @param {Array.<string>} style
  ##
  addStyle: (style) ->
    style = [style] if not Array.isArray style
    @style = @style.concat style

  ##
  # Creates an Event from an Event-like object. Used for deserialization.
  ##
  @wrap: (obj) ->
    return obj if obj instanceof Event
    event = new Event obj.type, obj.name, obj.args...
    event.setContext obj.context.server, obj.context.channel
    event

exports.Event = Event