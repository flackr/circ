exports = window

class AbstractMessageHandler
  constructor: (source) ->
    @source = source
    @handlers ?= {} 

  handle: (type, params...) ->
    assert @canHandle(type)
    @handlers[type].apply @source, params

  canHandle: (type) ->
    return @handlers[type]?

exports.AbstractMessageHandler = AbstractMessageHandler