exports = window

class RemoteConnection extends EventEmitter

  @PORT: 1329

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
    else
      socket = new net.RemoteSocket
      @_socketMap[server] = socket
    socket

  broadcastUserInput: (userInput) ->
    userInput.on 'command', (event) =>
      return if event.name in ['make-server', 'add-device', 'close-sockets', 'z', 'z2', 'z3']
      @_broadcast 'user_input', event

  broadcastSocketData: (socket, server) ->
    socket.onAny (type, data) =>
      if type is 'data'
        data = new Uint8Array data
      @_broadcast 'socket_data', server, type, data

  _broadcast: (type, args...) ->
    for id, device of @_deviceMap
      device.send type, args

  addDevice: (device) ->
    device.connect (success) =>
      @_addConnectedDevice device if success

  _addConnectedDevice: (device) =>
    @enable()
    @_deviceMap[device.id] = device
    device.on 'user_input', @_emitUserInput
    device.on 'socket_data', @_emitSocketData
    device.on 'connection_message', @_emitConnectionMessage

  _emitUserInput: (event) =>
    @emit event.type, Event.wrap event

  _emitSocketData: (server, type, data) =>
    if type is 'data'
      data = irc.util.dataViewToArrayBuffer data
    @_socketMap[server]?.emit type, data

  _emitConnectionMessage: (type, args...) =>
    @emit type, args...

  close: ->
    for id, device of @_deviceMap
      device.close()
    @_thisDevice.close()

  isEnabled: ->
    @_enabled

  enable: ->
    @_enabled = true

  isServer: ->
    @_isServer

  ##
  # Make this device connect through another device, as opposted to connecting
  # directly to the IRC server.
  ##
  makeServer: (state) ->
    @_isServer = true
    @_broadcast 'connection_message', 'irc_state', state

  ##
  # Begin listening to incoming TCP connections and broadcast information to them.
  ##
  makeClient: ->
    @_isServer = false

exports.RemoteConnection = RemoteConnection