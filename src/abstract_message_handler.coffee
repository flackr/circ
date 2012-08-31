exports = window

class AbstractMessageHandler
  constructor: (source=this) ->
    @source = source
    @handlers ?= {}

  setSource: (source) ->
    @source = source

  handle: (type, params...) ->
    assert @canHandle(type)
    @handlers[type].apply @source, params

  canHandle: (type) ->
    return @handlers[type]?

exports.AbstractMessageHandler = AbstractMessageHandler