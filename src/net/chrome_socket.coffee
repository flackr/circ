exports = window.net ?= {}

##
# A socket connected to an IRC server. Uses chrome.socket.
##
class ChromeSocket extends net.AbstractTCPSocket
  connect: (addr, port) ->
    @_active()
    chrome.socket.create 'tcp', {}, (si) =>
      @socketId = si.socketId
      if @socketId > 0
        chrome.socket.connect @socketId, addr, port, @_onConnect
      else
        return @emit 'error', "couldn't create socket"

  _onConnect: (rc) =>
    if rc < 0
      # Can get -109, -105, -102 when entering a server we can't connect to
      # TODO make better error messages
      @emit 'error', "couldn't connect to socket: " + rc
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
        @emit 'drain'
      else
        console.error "Waaah can't handle non-complete writes"

  close: ->
    chrome.socket.disconnect @socketId if @socketId?
    @emit 'close'

exports.ChromeSocket = ChromeSocket
