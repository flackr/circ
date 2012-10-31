exports = window

class Event
  constructor: (@type, @name, @args...) ->
    @context = {}
    @style = []
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

  @wrap: (obj) ->
    return obj if obj instanceof Event
    event = new Event obj.type, obj.name, obj.args...
    event.setContext obj.context.server, obj.context.channel
    event

exports.Event = Event