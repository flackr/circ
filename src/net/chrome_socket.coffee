exports = window.net ?= {}

class ChromeSocket extends net.AbstractTCPSocket
  connect: (host, port) ->
    @_active()
    go = (err, addr) =>
      return @emit 'error', "couldn't resolve: #{err}" if err
      @_active()
      chrome.socket.create 'tcp', {}, (si) =>
        @socketId = si.socketId
        if @socketId > 0
          chrome.socket.connect @socketId, addr, port, @_onConnect
        else
          return @emit 'error', "couldn't create socket"

    if /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$/.test host
      go null, host
    else
      ChromeSocket.resolve host, go

  _onConnect: (rc) =>
    if rc < 0
      # Can get -109, -105, -102 when entering a server we can't connect to
      # TODO make better error messages
      @emit 'error', rc
    else
      @emit 'connect'
      chrome.socket.read @socketId, @_onRead

  _onRead: (readInfo) =>
    console.error "Bad assumption: got -1 in _onRead" if readInfo.resultCode is -1
    @_active()
    if readInfo.resultCode < 0
      @emit 'error', readInfo.resultCode
    else if readInfo.resultCode is 0
      @emit 'end'
      @close() # TODO: half-open sockets
    if readInfo.data.byteLength
      @emit 'data', readInfo.data
      chrome.socket.read @socketId, @_onRead

  write: (data) ->
    @_active()
    chrome.socket.write @socketId, data, (writeInfo) =>
      if writeInfo.resultCode < 0
        console.error "SOCKET ERROR on write: ", writeInfo.resultCode
      if writeInfo.bytesWritten == data.byteLength
        @emit 'drain' # TODO not sure if this works, don't rely on this message
      else
        console.error "Waaah can't handle non-complete writes"

  close: ->
    chrome.socket.disconnect @socketId
    @emit 'close'

  @resolve: (host, cb) ->
    chrome.experimental.dns.resolve host, (res) ->
      if res.resultCode is 0
        cb(null, res.address)
      else
        cb(res.resultCode)

exports.ChromeSocket = ChromeSocket
