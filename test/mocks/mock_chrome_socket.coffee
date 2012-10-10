exports = window.mocks ?= {}

class ChromeSocket extends net.AbstractTCPSocket
  @useMock: ->
    net.ChromeSocket = ChromeSocket

  constructor: ->
    super

  connect: (host, port) ->

  write: (data) ->
    @_active()
    irc.util.fromSocketData data, ((msg) => @received msg)

  close: ->
    @emit 'close', 'socket error'

  received: (msg) ->
    @emit 'drain'

  respond: (type, args...) ->
    @_active()
    @emit type, args...

  respondWithData: (msg) ->
    @_active()
    msg += '\r\n'
    irc.util.toSocketData msg, ((data) => @respond 'data', data)

exports.ChromeSocket = ChromeSocket
