exports = window

class AbstractMessageHandler
  constructor: (source=this) ->
    @source = source
    @handlers ?= {}

  setSource: (source) ->
    @source = source

  addHandler: (handler) ->
    (@handlers[n] = f for n, f of handler.handlers)

  handle: (type, params...) ->
    assert @canHandle(type)
    @handlers[type].apply @source, params

  canHandle: (type) ->
    @handlers[type]?

exports.AbstractMessageHandler = AbstractMessageHandler