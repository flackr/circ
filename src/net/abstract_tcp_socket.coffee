exports = window.net ?= {}

# Abstract TCP socket.
# Events emitted:
# - 'connect': the connection succeeded, proceed.
# - 'data': data received. Argument is the data (array of longs, atm)
# - 'end': the other end sent a FIN packet, and won't accept any more data.
# - 'error': an error occurred. The socket is pretty much hosed now. (TODO:
#    investigate how node deals with errors. The docs say 'close' gets sent right
#    after 'error', so they probably destroy the socket.)
# - 'close': emitted when the socket is fully closed.
# - 'drain': emitted when the write buffer becomes empty

class AbstractTCPSocket extends EventEmitter
  connect: (port, host) ->

  write: (data) ->

  close: ->

  setTimeout: (ms, callback) ->
    if ms > 0
      @timeout = setTimeout (=> @emit 'timeout'), ms
      @timeout_ms = ms
      @once 'timeout', callback if callback
    else if ms == 0
      clearTimeout @timeout
      @removeListener 'timeout', callback if callback
      @timeout = null
      @timeout_ms = 0

   _active: ->
     if @timeout
      clearTimeout @timeout
      @timeout = setTimeout (=> @emit 'timeout'), @timeout_ms

exports.AbstractTCPSocket = AbstractTCPSocket
