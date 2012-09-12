exports = window

class MessageHandler
  constructor: (source=this) ->
    @_source = source
    @_handlerMap ?= {}
    @_mergedHandlers = []

  setSource: (source) ->
    @_source = source

  listenTo: (emitter) ->
    for type of @_handlerMap
      emitter.on type, (args...) => @handle type, args...
    for handler in @_mergedHandlers
      handler.listeneTo emitter

  merge: (handlerObject) ->
    @_mergedHandlers.push handlerObject

  registerHandlers: (handlers) ->
    for type, handler of handlers
      @registerHandler type, handler

  registerHandler: (type, handler) ->
    @_handlerMap[type] = handler

  handle: (type, params...) ->
    assert @canHandle(type)
    @_handlerMap[type]?.apply @_source, params
    for handler in @_mergedHandlers
      handler._handlerMap[type]?.apply @_source, params

  canHandle: (type) ->
    return true if type of @_handlerMap
    for handler in @_mergedHandlers
      return true if handler.canHandle(type)
    return false

exports.MessageHandler = MessageHandler