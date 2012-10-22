exports = window

class RemoteConnection extends EventEmitter

  constructor: ->
    super
    @_isServer = true
    @_devices = {}
    @_ircSocketMap = {}
    @_thisDevice = {}
    @_getState = -> {}
    RemoteDevice.getOwnDevice @_onHasOwnDevice

  _onHasOwnDevice: (device) =>
    @_thisDevice = device
    @_thisDevice.listenForNewDevices @_addClientDevice

  _addClientDevice: (device) =>
    @_addDevice device
    @_broadcast 'connection_message', 'irc_state', @_getState()

  _addDevice: (device) ->
    @_devices[device.id] = device
    device.on 'user_input', @_emitUserInput
    device.on 'socket_data', @_emitSocketData
    device.on 'connection_message', @_emitConnectionMessage

  getConnectionInfo: ->
    @_thisDevice

  setStateGenerator: (getState) ->
    @_getState = getState

  createSocket: (server) ->
    if @isServer()
      socket = new net.ChromeSocket
      @broadcastSocketData socket, server
    else
      socket = new net.RemoteSocket
      @_ircSocketMap[server] = socket
    socket

  broadcastUserInput: (userInput) ->
    userInput.on 'command', (event) =>
      @_broadcast 'user_input', event

  broadcastSocketData: (socket, server) ->
    socket.onAny (type, data) =>
      if type is 'data'
        data = new Uint8Array data
      @_broadcast 'socket_data', server, type, data

  _broadcast: (type, args...) ->
    for id, device of @_devices
      device.send type, args

  connectToServer: (addr, port) ->
    device = @_createServerDevice addr, port
    device.connect (success) =>
      @_makeClient() if success

  _createServerDevice: (addr, port) ->
    device = new RemoteDevice addr, port
    @_addDevice device
    device

  _emitUserInput: (event) =>
    @emit event.type, Event.wrap event

  _emitSocketData: (server, type, data) =>
    if type is 'data'
      data = irc.util.dataViewToArrayBuffer data
    @_ircSocketMap[server]?.emit type, data

  _emitConnectionMessage: (type, args...) =>
    @emit type, args...

  close: ->
    for id, device of @_devices
      device.close()
    @_thisDevice.close()

  isServer: ->
    @_isServer

  _makeClient: ->
    @_isServer = false

exports.RemoteConnection = RemoteConnection