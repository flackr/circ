exports = window.net ?= {}

class MockSocket extends net.AbstractTCPSocket
  constructor: ->
    super

  connect: (host, port) ->

  write: (data) ->
    irc.util.fromSocketData data, ((msg) => @received msg)

  close: ->

  setTimeout: (ms, callback) ->

  received: (msg) ->
    @emit 'drain'

  respond: (type, args...) ->
    @emit type, args...

  respondWithData: (msg) ->
    irc.util.toSocketData msg, ((data) => @respond 'data', data)

exports.MockSocket = MockSocket
