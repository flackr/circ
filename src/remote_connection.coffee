exports = window

##
# Handles sending and receiving data from connected devices running different
# instances of CIRC.
##
class RemoteConnection extends EventEmitter

  constructor: ->
    super
    @serverDevice = undefined
    @_connectingTo = undefined
    @_type = undefined
    @devices = []
    @_ircSocketMap = {}
    @_thisDevice = {}
    @_state = 'device_state'
    @_getIRCState = ->
    @_getChatLog = ->
    RemoteDevice.getOwnDevice @_onHasOwnDevice

  setPassword: (password) ->
    @_password = password

  _getAuthToken: (value) =>
    hex_md5 @_password + value

  getConnectionInfo: ->
    @_thisDevice

  getState: ->
    if @_state is 'device_state'
      return 'finding_port' unless @_thisDevice.port
      @_thisDevice.getState()
    else
      @_state

  setIRCStateFetcher: (getState) ->
    @_getIRCState = getState

  setChatLogFetcher: (getChatLog) ->
    @_getChatLog = getChatLog

  _onHasOwnDevice: (device) =>
    @_thisDevice = device
    if @_thisDevice.getState() is 'no_addr'
      @_log 'w', "Wasn't able to find address of own device"
      @emit 'no_addr'
      @_thisDevice.searchForAddress => @_onHasOwnDevice @_thisDevice
      return
    @emit 'found_addr'
    @_thisDevice.listenForNewDevices @_addUnauthenticatedDevice

  _addUnauthenticatedDevice: (device) =>
    @_log 'adding unauthenticated device', device.id
    device.getAddr =>
      @_log 'found unauthenticated device addr', device.addr
      device.on 'authenticate', @_authenticateDevice

  _authenticateDevice: (device, authToken) =>
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
    device.send 'connection_message', ['irc_state', @_getIRCState()]
    device.send 'connection_message', ['chat_log', @_getChatLog()]

  _addDevice: (newDevice) ->
    for device in @devices
      device.close() if device.addr is newDevice.addr
    @devices.push newDevice

  _listenToDevice: (device) ->
    device.on 'user_input', @_onUserInput
    device.on 'socket_data', @_onSocketData
    device.on 'connection_message', @_onConnectionMessage
    device.on 'closed', @_onDeviceClosed
    device.on 'no_port', => @emit 'no_port'

  _onUserInput: (device, event) =>
    if @isServer()
      @_broadcast device, 'user_input', event
    @emit event.type, Event.wrap event

  _onSocketData: (device, server, type, data) =>
    if type is 'data'
      data = irc.util.dataViewToArrayBuffer data
    @_ircSocketMap[server]?.emit type, data

  _onConnectionMessage: (device, type, args...) =>
    if type is 'irc_state'
      isValid = @_onIRCState device, args
      return unless isValid
    @emit type, args...

  _onIRCState: (device, args) ->
    if @getState() isnt 'connecting'
      @_log 'w', "got IRC state, but we're not connecting to a server -",
          device.toString(), args
      device.close()
      return false
    @_setServerDevice device
    @_becomeClient()
    true

  _setServerDevice: (device) ->
    @serverDevice?.close()
    @serverDevice = device

  _onDeviceClosed: (closedDevice) =>
    if @_deviceIsClient closedDevice
      @emit 'client_parted', closedDevice

    if @_deviceIsServer(closedDevice) and @getState() is 'connected'
      @_log 'w', 'lost connection to server -', closedDevice.addr
      @_state = 'device_state'
      @_type = undefined
      @emit 'server_disconnected'

    else if closedDevice.equals(@_connectingTo) and @getState() isnt 'connected'
      @emit 'invalid_server'

    for device, i in @devices
      @devices.splice i, 1 if device.id is closedDevice.id
      break

  _deviceIsServer: (device) ->
    device?.equals @serverDevice

  _deviceIsClient: (device) ->
    return false if device.equals @serverDevice or device.equals @_thisDevice
    for clientDevice in @devices
      return true if device.equals clientDevice
    return false

  ##
  # Create a socket for the given server. A fake socket is used when using
  # another devices IRC connection.
  # @param {string} server The name of the IRC server that the socket is
  #     connected to.
  ##
  createSocket: (server) ->
    if @isClient()
      socket = new net.RemoteSocket
      @_ircSocketMap[server] = socket
    else
      socket = new net.ChromeSocket
      @broadcastSocketData socket, server
    socket

  broadcastUserInput: (userInput) ->
    userInput.on 'command', (event) =>
      unless event.name in ['network-info', 'join-server', 'make-server', 'about']
        @_broadcast 'user_input', event

  broadcastSocketData: (socket, server) ->
    socket.onAny (type, data) =>
      if type is 'data'
        data = new Uint8Array data
      @_broadcast 'socket_data', server, type, data

  _broadcast: (opt_blacklistedDevice, type, args...) ->
    if typeof opt_blacklistedDevice is "string"
      args = [type].concat(args)
      type = opt_blacklistedDevice
      blacklistedDevice = undefined
    else
      blacklistedDevice = opt_blacklistedDevice

    for device in @devices
      device.send type, args unless device.equals blacklistedDevice

  disconnectDevices: ->
    for device in @devices
      device.close()
    @becomeIdle()

  waitForPort: (callback) ->
    if @getState() is 'found_port'
      return callback true
    if @getState() is 'no_port' or @getState() is 'no_addr'
      return callback false
    @_thisDevice?.once 'found_port', => callback true
    @_thisDevice?.once 'no_port', => callback false
    @once 'no_addr', => callback false

  becomeServer: ->
    if @isClient()
      @disconnectDevices()
    @_type = 'server'
    @_state = 'device_state'

  becomeIdle: ->
    @_type = 'idle'
    @_state = 'device_state'

  _becomeClient: ->
    @_log 'this device is now a client of', @serverDevice.toString()
    @_type = 'client'
    @_state = 'connected'
    @_addDevice @serverDevice

  disconnectFromServer: ->
    @serverDevice?.close()

  ##
  # Connect to a remote server. The IRC connection of the remote server will
  # replace the local connection.
  # @params {{port: number, addr: string}} connectInfo
  ##
  connectToServer: (connectInfo) ->
    if @_connectingTo
      deviceToClose = @_connectingTo
      @_connectingTo = undefined
      deviceToClose.close()

    @_state = 'connecting'
    device = new RemoteDevice connectInfo.addr, connectInfo.port
    @_connectingTo = device
    @_listenToDevice device
    device.connect (success) =>
      if success then @_onConnectedToServer device
      else @_onFailedToConnectToServer device

  _onConnectedToServer: (device) ->
    @_log 'connected to server', device.toString()
    @emit 'server_found', device

  _onFailedToConnectToServer: (device) ->
    @_state = 'device_state'
    @emit 'invalid_server', device

  finalizeConnection: ->
    @_state = 'connecting'
    @_connectingTo.sendAuthentication @_getAuthToken

  isServer: ->
    @_type is 'server'

  isClient: ->
    @_type is 'client'

  isIdle: ->
    @_type is 'idle'

  isInitializing: ->
    @_type is undefined


exports.RemoteConnection = RemoteConnection