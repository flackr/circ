exports = window

class RemoteDevice extends EventEmitter

  constructor: (connectionId) ->
    super
    @_receivedMessages = ''
    @_port = RemoteConnection.PORT
    if typeof connectionId is 'string'
      @_addr = connectionId
    else
      @_socketId = connectionId
      @_listenForData()
    @id = connectionId

  @getOwnDevice: (callback) ->
    chrome.socket.getNetworkList (networkInfoList) =>
      # TODO ideally we'd listen on all addresses, not just one
      possibleAddrs = (networkInfo.address for networkInfo in networkInfoList)
      console.log 'possible addresses:', JSON.stringify possibleAddrs
      callback new RemoteDevice possibleAddrs[possibleAddrs.length - 1]

  listenForNewDevices: (callback) ->
    chrome.socket.create 'tcp', {}, (socketInfo) =>
      @_socketId = socketInfo.socketId
      chrome.socket.listen @_socketId, '0.0.0.0', @_port, (rc) =>
        console.log 'now listening on', '0.0.0.0', @_port, '- RC:', rc
        @_acceptNewConnection callback

  _acceptNewConnection: (callback) ->
    chrome.socket.accept @_socketId, (acceptInfo) =>
      console.log 'accepted a connection!', acceptInfo.resultCode, acceptInfo.socketId
      callback new RemoteDevice acceptInfo.socketId
      @_acceptNewConnection callback

  send: (type, args) ->
    msg = JSON.stringify { type, args }
    msg = msg.length + '$' + msg
    irc.util.toSocketData msg, (data) =>
      chrome.socket.write @_socketId, data, (writeInfo) =>
        if writeInfo.resultCode < 0
          console.error "send: error on write: ", writeInfo.resultCode, type, args
        if writeInfo.bytesWritten != data.byteLength
          console.error "Waaah can't handle non-complete writes"

  connect: (callback) ->
    if @_socketId
      console.warn 'already have a connection! No need to connect again'
      return
    chrome.socket.create 'tcp', {}, (socketInfo) =>
      @_socketId = socketInfo.socketId
      console.log 'created a connection socket', @_socketId
      chrome.socket.connect @_socketId, @_addr, @_port, (result) => @_onConnect result, callback

  _onConnect: (result, callback) =>
    if result < 0
      console.error "Failed to connect to", @_addr
      callback false
    else
      console.log "connected to", @_addr
      @_listenForData()
      callback true

  close: ->
    if @_socketId
      chrome.socket.destroy @_socketId
      console.warn 'closed', @_socketId

  _listenForData: ->
    chrome.socket.read @_socketId, (readInfo) =>
      if readInfo.resultCode < 0
        console.error 'onRead: bad read', readInfo.resultCode, 'socket:', @_socketId
      else if readInfo.resultCode is 0
        console.error 'onRead: got result code 0, should close now'
      else if readInfo.data.byteLength
        irc.util.fromSocketData readInfo.data, (partialMessage) =>
          @_receivedMessages += partialMessage
          completeMessages = @_parseReceivedMessages()
          for json in completeMessages
            data = JSON.parse json
            @emit data.type, data.args...
        @_listenForData()
      else
        console.error 'onRead: got no data!'

  _parseReceivedMessages: (result=[]) ->
    return result unless @_receivedMessages
    prefixEnd = @_receivedMessages.indexOf('$')
    return result unless prefixEnd >= 0
    length = parseInt @_receivedMessages[..prefixEnd - 1]
    return result unless @_receivedMessages.length > prefixEnd + length

    message = @_receivedMessages[prefixEnd + 1 .. prefixEnd + length]
    result.push message
    @_receivedMessages = @_receivedMessages[prefixEnd + length + 1..]
    return @_parseReceivedMessages result

exports.RemoteDevice = RemoteDevice