exports = window.chat ?= {}

##
# Handles sharing an IRC connections between multiple devices.
##
class RemoteConnectionHandler

  # Number of ms to wait for a connection to be established to a server device
  # before using our own IRC connection.
  @SERVER_DEVICE_CONNECTION_WAIT = 500

  # Number of ms to wait before trying to reconnect to the server device.
  @SERVER_DEVICE_RECONNECTION_WAIT = 500
  @SERVER_DEVICE_RECONNECTION_MAX_WAIT = 5 * 1000

  constructor: (chat) ->
    @_log = getLogger this
    @_chat = chat

  ##
  # Set the storage handler which is used to store IRC states and which device
  # is acting as the server
  # @param {SyncStorage} storage
  ##
  setStorageHandler: (storage) ->
    @_storage = storage
    @_remoteConnection.setIRCStateFetcher =>
      @_storage.getState @_chat
    @_remoteConnection.setChatLogFetcher =>
      @_chat.messageHandler.getChatLog()

  ##
  # Set the remote connection which handles sending and receiving data from
  # connected devices.
  # @param {RemoteConnection} remoteConnection
  ##
  setRemoteConnection: (remoteConnection) ->
    @_remoteConnection = remoteConnection
    @_listenToRemoteConnectionEvents()

  _listenToRemoteConnectionEvents: ->
    @_chat.userCommands.listenTo @_remoteConnection

    @_remoteConnection.on 'found_addr', =>
      @determineConnection()

    @_remoteConnection.on 'on_addr', =>
      @_useOwnConnection()

    @_remoteConnection.on 'no_port', =>
      @_useOwnConnection()

    @_remoteConnection.on 'server_found', =>
      @_remoteConnection.finalizeConnection()

    @_remoteConnection.on 'invalid_server', (connectInfo) =>
      unless @_reconnectionAttempt
        @_displayFailedToConnect connectInfo
      @_reconnectionAttempt = false
      @_useOwnConnection()
      @_tryToReconnectToServerDevice()

    @_remoteConnection.on 'irc_state', (state) =>
      @_reconnectionAttempt = false
      @_storage.pause()
      @_chat.closeAllConnections()
      @_stopServerReconnectAttempts()
      @_storage.loadState @_chat, state

    @_remoteConnection.on 'chat_log', (chatLog) =>
      @_chat.messageHandler.replayChatLog chatLog
      connInfo = @_remoteConnection.serverDevice
      return unless connInfo
      @_chat.displayMessage 'notice', @_chat.getCurrentContext(), "Connected through " +
          "server device #{connInfo.toString()}"

    @_remoteConnection.on 'server_disconnected', =>
      @_serverDisconnected = true
      @determineConnection()
      @_serverDisconnected = false

    @_remoteConnection.on 'client_joined', (client) =>
      @_chat.displayMessage 'notice', @_chat.getCurrentContext(), client.addr +
          ' connected to this device'
      @_chat.updateStatus()

    @_remoteConnection.on 'client_parted', (client) =>
      @_chat.displayMessage 'notice', @_chat.getCurrentContext(), client.addr +
          ' disconnected from this device'
      @_chat.updateStatus()

  _displayFailedToConnect: (connectInfo) ->
    connectInfo = @_storage.serverDevice
    return unless connectInfo
    @_chat.displayMessage 'notice', @_chat.getCurrentContext(), "Unable to connect to " +
        "server device #{connectInfo.addr} on port #{connectInfo.port}"

  _displayLostConnectionMessage: ->
    @_chat.displayMessage 'notice', @_chat.getCurrentContext(), "Lost connection to " +
        "server device. Attempting to reconnect..."

  ##
  # Determine if we should connect directly to IRC or connect through another
  # device's IRC connection.
  ##
  determineConnection: ->
    @_log 'determining connection...', @_remoteConnection.getConnectionInfo().addr,
        @_storage.loadedServerDevice, @_storage.password
    return unless @_remoteConnection.getConnectionInfo().addr and
        @_storage.loadedServerDevice and @_storage.password
    @_log 'can make a connection - device:', @_storage.serverDevice,
        '- is server?', @shouldBeServerDevice()

    if @_storage.serverDevice and not @shouldBeServerDevice()
      @_useServerDeviceConnection()
    else
      @_useOwnConnection()

  _useServerDeviceConnection: ->
    clearTimeout @_useOwnConnectionTimeout
    usingServerDeviceConnection = @_remoteConnection.getState() in ['connected', 'connecting']
    sameConnection = @_remoteConnection.serverDevice?.usesConnection @_storage.serverDevice
    return if usingServerDeviceConnection and sameConnection
    @_log 'automatically connecting to', @_storage.serverDevice
    if @_remoteConnection.isInitializing()
      @_useOwnConnectionTimeout = setTimeout(
          @_useOwnConnectionWhileWaitingForServer,
          RemoteConnectionHandler.SERVER_DEVICE_CONNECTION_WAIT)
    @_remoteConnection.connectToServer @_storage.serverDevice

  _tryToReconnectToServerDevice: ->
    clearTimeout @_serverDeviceReconnectTimeout
    @_serverDeviceReconnectBackoff ?=
        RemoteConnectionHandler.SERVER_DEVICE_RECONNECTION_WAIT
    @_serverDeviceReconnectTimeout = setTimeout @_reconnect,
        @_serverDeviceReconnectBackoff

  _reconnect: =>
    @_reconnectionAttempt = true
    @_serverDeviceReconnectBackoff *= 1.2
    if @_serverDeviceReconnectBackoff >
          RemoteConnectionHandler.SERVER_DEVICE_RECONNECTION_MAX_WAIT
      @_serverDeviceReconnectBackoff =
          RemoteConnectionHandler.SERVER_DEVICE_RECONNECTION_MAX_WAIT
    if not (@_remoteConnection.getState() in ['connecting', 'connected'])
      @determineConnection()

  _stopServerReconnectAttempts: ->
    clearTimeout @_serverDeviceReconnectTimeout
    @_serverDeviceReconnectBackoff =
        RemoteConnectionHandler.SERVER_DEVICE_RECONNECTION_WAIT

  _useOwnConnectionWhileWaitingForServer: =>
    return unless @_remoteConnection.isInitializing()
    @_remoteConnection.becomeIdle()
    connectInfo = @_chat.syncStorage.serverDevice
    @_resumeIRCConnection =>
      @_displayFailedToConnect connectInfo

  _useOwnConnection: ->
    clearTimeout @_useOwnConnectionTimeout
    usingServerDeviceConnection = @_remoteConnection.getState() in ['connected']
    if usingServerDeviceConnection
      @_remoteConnection.disconnectFromServer()
      return

    if @shouldBeServerDevice()
      @_stopServerReconnectAttempts()
      @_tryToBecomeServerDevice()
      return

    shouldResumeIRCConn = @_notUsingOwnIRCConnection()
    return if @_remoteConnection.isIdle()
    @_stopBeingServerDevice()
    @_resumeIRCConnection() if shouldResumeIRCConn

  _tryToBecomeServerDevice: ->
    shouldResumeIRCConn = @_notUsingOwnIRCConnection()
    if @_remoteConnection.getState() is 'finding_port'
      @_remoteConnection.waitForPort => @determineConnection()
      @_log 'should be server, but havent found port yet...'
      return

    if @_remoteConnection.getState() is 'no_port'
      @_stopBeingServerDevice() if @_remoteConnection.isServer()
    else if not @_remoteConnection.isServer() or
        @_storage.serverDevice.port isnt @_remoteConnection.getConnectionInfo().port
      @_becomeServerDevice()
    else return
    @_resumeIRCConnection() if shouldResumeIRCConn

  _notUsingOwnIRCConnection: ->
    @_remoteConnection.isInitializing() or
        @_remoteConnection.isClient()

  _stopBeingServerDevice: ->
    if @_remoteConnection.isServer()
      @_log 'stopped being a server device'
      @_remoteConnection.disconnectDevices()
    else
      @_remoteConnection.becomeIdle()

  shouldBeServerDevice: ->
    # TODO check something stored in local storage, not IP addr which can change
    @_storage.serverDevice?.addr in
        @_remoteConnection.getConnectionInfo().possibleAddrs

  _becomeServerDevice: ->
    @_log 'becoming server device'
    unless @_remoteConnection.isInitializing()
      @_chat.displayMessage 'notice', @_chat.getCurrentContext(), 'Now accepting ' +
          'connections from other devices'
    @_remoteConnection.becomeServer()
    @_storage.becomeServerDevice @_remoteConnection.getConnectionInfo()

  _resumeIRCConnection: (opt_callback) ->
    @_log 'resuming IRC conn'
    @_chat.closeAllConnections()
    shouldDisplayLostConnectionMessage = @_serverDisconnected
    @_storage.restoreSavedState @_chat, =>
      @_chat.messageHandler.replayChatLog()
      @_storage.resume()
      @_displayLostConnectionMessage() if shouldDisplayLostConnectionMessage
      opt_callback?()

exports.RemoteConnectionHandler = RemoteConnectionHandler