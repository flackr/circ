exports = window

class RemoteDevice extends EventEmitter

  # Begin at this port and increment by one until an open port is found.
  @BASE_PORT: 1329
  @MAX_CONNECTION_ATTEMPTS: 30
  @FINDING_PORT: -1
  @PORT_NOT_FOUND: -2

  constructor: (addr, port) ->
    super
    @_receivedMessages = ''
    @id = addr
    if typeof addr is 'string'
      @_initFromAddress addr, port
    else
      @_initFromSocketId addr

  _initFromAddress: (@addr, @port) ->

  _initFromSocketId: (@_socketId) ->
    @_listenForData()

  @getOwnDevice: (callback) ->
    chrome.socket.getNetworkList (networkInfoList) =>
      possibleAddrs = (networkInfo.address for networkInfo in networkInfoList)
      device = new RemoteDevice possibleAddrs[0], RemoteDevice.FINDING_PORT
      device.possibleAddrs = possibleAddrs
      callback device

  ##
  # Called when the device is your own device. Listens for connecting client
  # devices.
  ##
  listenForNewDevices: (callback) ->
    chrome.socket.create 'tcp', {}, (socketInfo) =>
      @_socketId = socketInfo.socketId
      @_listenOnValidPort callback

  ##
  # Attempt to listen on the default port, then increment the port by a random
  # amount if the attempt fails and try again.
  ##
  _listenOnValidPort: (callback, port) =>
    port = RemoteDevice.BASE_PORT unless port >= 0
    chrome.socket.listen @_socketId, '0.0.0.0', port, (result) =>
      if result < 0
        if port - RemoteDevice.BASE_PORT > RemoteDevice.MAX_CONNECTION_ATTEMPTS
          console.error "Couldn't listen to 0.0.0.0 on any attempted ports"
          @port = RemoteDevice.PORT_NOT_FOUND
          return
        @_listenOnValidPort callback, port + Math.floor Math.random() * 100
      else
        @port = port
        @_acceptNewConnection callback

  _acceptNewConnection: (callback) ->
    console.log 'Now listening to 0.0.0.0 on port', @port
    chrome.socket.accept @_socketId, (acceptInfo) =>
      callback new RemoteDevice acceptInfo.socketId
      console.log 'Connected to client', @_socketId
      @_acceptNewConnection callback

  send: (type, args) ->
    msg = JSON.stringify { type, args }
    msg = msg.length + '$' + msg
    irc.util.toSocketData msg, (data) =>
      chrome.socket.write @_socketId, data, (writeInfo) =>
        if writeInfo.resultCode < 0
          console.warn "failed to send:", type, args, writeInfo.resultCode
        else if writeInfo.bytesWritten != data.byteLength
          console.warn "failed to send:", type, args, '(non-complete write)'
        else
          console.warn 'successfully sent', type, args

  ##
  # Called when the device represents a remote server. Creates a connection
  # to that remote server.
  ##
  connect: (callback) ->
    if @_socketId
      console.warn 'already have a connection! No need to connect again'
      return
    chrome.socket.create 'tcp', {}, (socketInfo) =>
      @_socketId = socketInfo.socketId
      chrome.socket.connect @_socketId, @addr, @port, (result) =>
        console.log 'Connected to server', @addr, 'on port', @port
        @_onConnect result, callback

  _onConnect: (result, callback) ->
    if result < 0
      console.error "Failed to connect to", @addr, 'on port', @port
      callback false
    else
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