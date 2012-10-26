exports = window

class RemoteConnection extends EventEmitter

  constructor: ->
    super
    @serverDevice = undefined
    @_type = 'server'
    @devices = []
    @_ircSocketMap = {}
    @_thisDevice = {}
    @_state = 'device_state'
    RemoteDevice.getOwnDevice @_onHasOwnDevice

  setPassword: (password) ->
    @_password = password

  getConnectionInfo: ->
    @_thisDevice

  getState: ->
    if @_state is 'device_state'
      return 'finding_port' unless @_thisDevice.port
      @_thisDevice.getState()
    else
      @_state

  _getAuthToken: (value) =>
    hex_md5 @_password + value

  _onHasOwnDevice: (device) =>
    @_thisDevice = device
    if @_thisDevice.getState() is 'no_port'
      @_log 'w', "Wasn't able to find address of own device"
      @emit 'no_port'
      return
    @emit 'found_addr'
    @_thisDevice.listenForNewDevices @_addUnauthenticatedDevice
    @_thisDevice.on 'found_port', =>
      @emit 'found_port', device.addr, device.port

  _addUnauthenticatedDevice: (device) =>
    @_log 'adding unauthenticated device', device.id
    device.getAddr =>
      @_log 'found unauthenticated device addr', device.addr
      device.on 'authenticate', (authToken) =>
        @_authenticateDevice device, authToken

  _authenticateDevice: (device, authToken) ->
    if authToken is @_getAuthToken device.addr
      @_addClientDevice device
    else
      @_log 'w', 'AUTH FAILED', @_getAuthToken(device.addr), 'should be', authToken
      device.close()

  _addClientDevice: (device) ->
    @_log 'auth passed, adding client device', device.id, device.addr
    @_listenToDevice device
    @_addDevice device
    @emit 'client_joined', device
    @_broadcast 'connection_message', 'irc_state', @_getState()

  _addDevice: (newDevice) ->
    for device in @devices
      device.close() if device.addr is newDevice.addr
    @devices.push newDevice

  _listenToDevice: (device) ->
    device.on 'user_input', @_emitUserInput
    device.on 'socket_data', @_emitSocketData
    device.on 'connection_message', @_emitConnectionMessage
    device.on 'closed', => @_onDeviceClosed device

  _emitUserInput: (event) =>
    @emit event.type, Event.wrap event

  _emitSocketData: (server, type, data) =>
    if type is 'data'
      data = irc.util.dataViewToArrayBuffer data
    @_ircSocketMap[server]?.emit type, data

  _emitConnectionMessage: (type, args...) =>
    if type is 'irc_state'
      @_makeClient() unless @isClient()
    @emit type, args...

  _onDeviceClosed: (closedDevice) ->
    for device, i in @devices
      @devices.splice i, 1 if device.id is closedDevice.id
      break

    if @_deviceIsClient closedDevice
      @emit 'client_parted', closedDevice

    else if @getState() is 'connected' and @_deviceIsServer closedDevice
      @_log 'w', 'lost connection to server -', closedDevice.addr
      @_state = 'device_state'
      @_type = 'server'
      @emit 'server_disconnected'

  _deviceIsServer: (device) ->
    device.id is @serverDevice?.id

  _deviceIsClient: (device) ->
    device.id isnt @serverDevice?.id and
        device.id isnt @_thisDevice?.id

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
      unless event.name in ['network-info', 'join-server']
        @_broadcast 'user_input', event

  broadcastSocketData: (socket, server) ->
    socket.onAny (type, data) =>
      if type is 'data'
        data = new Uint8Array data
      @_broadcast 'socket_data', server, type, data

  _broadcast: (type, args...) ->
    for device in @devices
      device.send type, args

  ##
  # Connect to a remote server. The IRC connection of the remote server will
  # replace the local connection.
  # @params {{port: number, addr: string}} connectInfo
  ##
  connectToServer: (connectInfo) ->
    @_state = 'connecting'
    @serverDevice = new RemoteDevice connectInfo.addr, connectInfo.port
    @_listenToDevice @serverDevice
    @serverDevice.connect (success) =>
      if success
        @_log 'successfully connected to server', connectInfo.addr, connectInfo.port
        @serverDevice.sendAuthentication @_getAuthToken
      else
        @emit 'invalid_server', connectInfo
        @_state = 'device_state'

  close: ->
    for device in @devices
      device.close()
    @_thisDevice.close()

  isServer: ->
    @_type is 'server' or @isOfficialServer()

  isClient: ->
    @_type is 'client'

  isOfficialServer: ->
    @_type is 'official_server'

  waitForPort: (callback) ->
    if @getState() is 'found_port'
      return callback true
    if @getState() is 'no_port'
      return callback false
    @on 'found_port', =>
      callback true
    @on 'no_port', =>
      callback false

  makeOfficialServer: ->
    wasClient = @isClient()
    @_type = 'official_server'
    if wasClient
      @serverDevice.close()
    @emit 'became_server'

  _makeClient: ->
    @_type = 'client'
    @_state = 'connected'
    @_addDevice @serverDevice

exports.RemoteConnection = RemoteConnection