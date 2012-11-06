exports = window

##
# Generic message handling class.
##
class MessageHandler
  constructor: () ->
    @_log = getLogger this
    @_handlers ?= {}
    @_mergedHandlers = []

  listenTo: (emitter) ->
    for type of @_handlers
      emitter.on type, (args...) => @handle type, args...

  merge: (handlerObject) ->
    @_mergedHandlers.push handlerObject

  registerHandlers: (handlers) ->
    for type, handler of handlers
      @registerHandler type, handler

  registerHandler: (type, handler) ->
    @_handlers[type] = handler

  handle: (@type, @params...) ->
    assert @canHandle @type
    @_handlers[@type]?.apply this, @params
    for handler in @_mergedHandlers when handler.canHandle @type
      handler.handle @type, @params...

  canHandle: (type) ->
    return true if type of @_handlers
    for handler in @_mergedHandlers
      return true if handler.canHandle(type)
    return false

exports.MessageHandler = MessageHandler