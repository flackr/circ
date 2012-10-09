exports = window.mocks ?= {}

class ChromeSocket extends net.AbstractTCPSocket
  @use: ->
    net.ChromeSocket = ChromeSocket

  constructor: ->
    super

  connect: (host, port) ->

  write: (data) ->
    @_active()
    irc.util.fromSocketData data, ((msg) => @received msg)

  close: ->

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
