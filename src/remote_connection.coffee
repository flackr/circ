exports = window

class RemoteConnection extends EventEmitter

  @PORT: 1329
  @USER_INPUT: 'user_input'
  @SOCKET_DATA: 'socket_data'
  @CONNECTION_MESSAGE: 'connection_message'

  constructor: ->
    super
    @_isEnabled = false
    @_deviceMap = {}
    @_socketMap = {}
    RemoteDevice.getOwnDevice @_onHasOwnDevice

  _onHasOwnDevice: (device) =>
    @_thisDevice = device
    @_thisDevice.listenForNewDevices @_addConnectedDevice

  createSocket: (server) ->
    if @isServer()
      socket = new net.ChromeSocket
      @broadcastSocketData socket, server
      console.log 'creating server socket'
    else
      socket = new net.RemoteSocket
      @_socketMap[server] = socket
      console.log 'creating remote socket'
    socket

  broadcastUserInput: (userInput) ->
    userInput.on 'command', (event) =>
      return if event.name in ['make-server', 'add-device', 'close-sockets', 'z', 'z2', 'z3']
      @_broadcast RemoteConnection.USER_INPUT, event

  broadcastSocketData: (socket, server) ->
    socket.onAny (type, data) =>
      if type is 'data'
        data = new Uint8Array data
      @_broadcast RemoteConnection.SOCKET_DATA, server, type, data

  _broadcast: (type, args...) ->
    for id, device of @_deviceMap
      device.send type, args

  addDevice: (device) ->
    device.connect (success) =>
      @_addConnectedDevice device if success

  _addConnectedDevice: (device) =>
    @enable()
    @_deviceMap[device.id] = device
    device.on 'message', @_onMessage

  _onMessage: (type, args) =>
    if type is RemoteConnection.USER_INPUT
      @_emitUserInput args...
    else if type is RemoteConnection.SOCKET_DATA
      @_emitSocketData args...
    else if type is RemoteConnection.CONNECTION_MESSAGE
      @_emitConnectionMessage args...
    else
      console.warn "received data from remote server of unknown type:", type, args

  _emitUserInput: (event) ->
    event = Event.wrap event
    console.log 'EMITTING user input', event.name,
        event.context.server, event.context.channel, event.args
    @emit event.type, event

  _emitSocketData: (server, type, data) ->
    console.log 'EMITTING socket data', type, data
    if type is 'data'
      data = irc.util.dataViewToArrayBuffer data
    @_socketMap[server]?.emit type, data

  _emitConnectionMessage: (type, args...) ->
    console.log 'EMITTING connection message', type, args
    @emit type, args...

  close: ->
    for id, device of @_deviceMap
      device.close()
    @_thisDevice.close()

  isEnabled: ->
    @_enabled

  enable: ->
    console.log 'is now enabled'
    @_enabled = true

  isServer: ->
    @_isServer

  ##
  # Make this device connect through another device, as opposted to connecting
  # directly to the IRC server.
  ##
  makeServer: (state) ->
    console.log 'is now server'
    @_isServer = true
    console.warn 'broadcasting connection info:', state
    @_broadcast RemoteConnection.CONNECTION_MESSAGE, 'irc_state', state

  ##
  # Begin listening to incoming TCP connections and broadcast information to them.
  ##
  makeClient: ->
    @_isServer = false

exports.RemoteConnection = RemoteConnection