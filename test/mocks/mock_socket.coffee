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

class MockSocket extends net.AbstractTCPSocket
  connect: (port, host) ->
    console.log 'MockSocket: connect(', port, host, ')'

  write: (data) ->
    console.log 'MockSocket: write(', data, ')'

  close: ->
    console.log 'MockSocket: close()'

  setTimeout: (ms, callback) ->
    console.log 'MockSocket: connect(', ms, callback, ')'

exports.MockSocket = MockSocket
