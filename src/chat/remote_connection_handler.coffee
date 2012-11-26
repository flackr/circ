exports = window.chat ?= {}

##
# Handles sharing an IRC connections between multiple devices.
##
class RemoteConnectionHandler

  # Number of ms to wait for a connection to be established to a server device
  # before using our own IRC connection.
  @SERVER_DEVICE_CONNECTION_WAIT = 650

  # If this many milliseconds go by after the user has connected to their own
  # IRC connection, we will notify them before switching to a remote server
  # connection.
  @NOTIFY_BEFORE_CONNECTING = 1500

  # Number of ms to wait before trying to reconnect to the server device.
  @SERVER_DEVICE_RECONNECTION_WAIT = 500
  @SERVER_DEVICE_RECONNECTION_MAX_WAIT = 5 * 1000

  constructor: (chat) ->
    @_log = getLogger this
    @_timer = new Timer()
    @_chat = chat
    @_addConnectionChangeListeners()
    chat.on 'tear_down', @_tearDown
    if not isOnline()
      @_chat.notice.prompt "No internet connection found. You will be unable to connect to IRC."

  _tearDown: =>
    @_removeConnectionChangeListeners()

  _addConnectionChangeListeners: ->
    $(window).on 'online', @_onOnline
    $(window).on 'offline', @_onOffline

  _removeConnectionChangeListeners: ->
    $(window).off 'online', @_onOnline
    $(window).off 'offline', @_onOffline

  ##
  # Set the storage handler which is used to store IRC states and which device
  # is acting as the server
  # @param {Storage} storage
  ##
  setStorageHandler: (storage) ->
    @_storage = storage
    @_remoteConnection.setIRCStateFetcher =>
      @_storage.getState()
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

  _onOnline: =>
    @_chat.notice.close()
    @_timer.start 'started_connection'
    @determineConnection()

  _onOffline: =>
    @_chat.notice.prompt "You lost connection to the internet. You will be unable to connect to IRC."
    @_chat.remoteConnection.disconnectDevices()

  _listenToRemoteConnectionEvents: ->
    @_chat.userCommands.listenTo @_remoteConnection

    @_remoteConnection.on 'found_addr', =>
      @determineConnection()

    @_remoteConnection.on 'on_addr', =>
      @_useOwnConnection()

    @_remoteConnection.on 'no_port', =>
      @_useOwnConnection()

     @_remoteConnection.on 'server_found', =>
      @_chat.notice.close()
      abruptSwitch = @_timer.elapsed('started_connection') >
          chat.RemoteConnectionHandler.NOTIFY_BEFORE_CONNECTING
      if abruptSwitch
        @_notifyConnectionAvailable()
      else
        @_remoteConnection.finalizeConnection()

    @_remoteConnection.on 'invalid_server', (connectInfo) =>
      if @_chat.remoteConnection.isInitializing()
        @_onConnected = => @_displayFailedToConnect connectInfo
      else if not @_reconnectionAttempt
        @_displayFailedToConnect connectInfo
      @_reconnectionAttempt = false

      @_useOwnConnection()
      @_tryToReconnectToServerDevice()

    @_remoteConnection.on 'irc_state', (state) =>
      @_timer.start 'started_connection'
      @_reconnectionAttempt = false
      @_storage.pause()
      @_chat.closeAllConnections()
      @_stopServerReconnectAttempts()
      @_storage.loadState state

    @_remoteConnection.on 'chat_log', (chatLog) =>
      @_chat.messageHandler.replayChatLog chatLog
      connInfo = @_remoteConnection.serverDevice
      return unless connInfo
      @_chat.displayMessage 'notice', @_chat.getCurrentContext(), "Connected through " +
          "server device #{connInfo.toString()}"

    @_remoteConnection.on 'server_disconnected', =>
      @_timer.start 'started_connection'
      unless @manuallyDisconnected
        @_onConnected = => @_displayLostConnectionMessage()
      @determineConnection()

    @_remoteConnection.on 'client_joined', (client) =>
      @_chat.displayMessage 'notice', @_chat.getCurrentContext(), client.addr +
          ' connected to this device'
      @_chat.updateStatus()

    @_remoteConnection.on 'client_parted', (client) =>
      @_chat.displayMessage 'notice', @_chat.getCurrentContext(), client.addr +
          ' disconnected from this device'
      @_chat.updateStatus()

  isManuallyConnecting: ->
    @_timer.start 'started_connection'

  _notifyConnectionAvailable: ->
    message = "Device discovered. Would you like to connect and use its IRC " +
        "connection? [connect]"
    @_chat.notice.prompt message, =>
      @_reconnectionAttempt = false
      @_chat.remoteConnection.finalizeConnection()

  _displayFailedToConnect: (connectInfo) ->
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
    return unless isOnline()

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
    return if @_alreadyConnectedToServerDevice()
    @_log 'automatically connecting to', @_storage.serverDevice
    if @_remoteConnection.isInitializing()
      @_useOwnConnectionIfServerTakesTooLong()
    @_remoteConnection.connectToServer @_storage.serverDevice

  _alreadyConnectedToServerDevice: ->
    usingServerDeviceConnection = @_remoteConnection.getState() in
        ['connected', 'connecting']
    isCurrentServerDevice = @_remoteConnection.serverDevice?.usesConnection(
        @_storage.serverDevice)
    return usingServerDeviceConnection and isCurrentServerDevice

  _useOwnConnectionIfServerTakesTooLong: ->
    @_useOwnConnectionTimeout = setTimeout =>
      @_useOwnConnectionWhileWaitingForServer()
    , RemoteConnectionHandler.SERVER_DEVICE_CONNECTION_WAIT

  _tryToReconnectToServerDevice: ->
    clearTimeout @_serverDeviceReconnectTimeout
    @_serverDeviceReconnectBackoff ?=
        RemoteConnectionHandler.SERVER_DEVICE_RECONNECTION_WAIT
    @_serverDeviceReconnectTimeout = setTimeout =>
      @_reconnect()
    , @_serverDeviceReconnectBackoff

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
    connectInfo = @_storage.serverDevice
    @_onConnected = =>
      @_displayFailedToConnect connectInfo
    @_resumeIRCConnection()

  _useOwnConnection: ->
    clearTimeout @_useOwnConnectionTimeout
    usingServerDeviceConnection = @_remoteConnection.getState() in ['connected']
    if usingServerDeviceConnection
      @manuallyDisconnected = true
      @_remoteConnection.disconnectFromServer()
      @manuallyDisconnected = false
      return

    if @shouldBeServerDevice()
      @_chat.notice.close()
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

  _resumeIRCConnection: ->
    @_timer.start 'started_connection'
    @_log 'resuming IRC conn'
    @_chat.closeAllConnections()
    @_storage.restoreSavedState =>
      @_onUsingOwnConnection()

  _onUsingOwnConnection: ->
    @_chat.switchToWindowByIndex 0
    @_chat.messageHandler.replayChatLog()
    @_storage.resume()
    @_onConnected?()
    @_onConnected = undefined
    @_chat.startWalkthrough() unless @_storage.completedWalkthrough

exports.RemoteConnectionHandler = RemoteConnectionHandler