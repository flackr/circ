exports = window.chat ?= {}

##
# Manages storage.
##
class Storage

  @STATE_ITEMS = ['nick', 'servers', 'channels', 'ignored_messages']
  @INITIAL_ITEMS = ['password', 'server_device', 'autostart']
  @INITIAL_ITEMS_LOCAL = ['completed_walkthrough']

  constructor: (chat) ->
    @_chat = chat
    @_log = getLogger this
    @_channels = []
    @_servers = []
    @_nick = undefined
    @_autostart = undefined
    @password = undefined
    @serverDevice = undefined
    chrome.storage.onChanged.addListener @_onChanged
    @pause()

  ##
  # Listen for storage changes.
  # If the password updated then change our own. If the password was cleared
  # then restore it.
  ##
  _onChanged: (changeMap, areaName) =>
    if changeMap.password
      @_onPasswordChange changeMap.password
    if changeMap.server_device
      @_onServerDeviceChange changeMap.server_device

  _onPasswordChange: (passwordChange) ->
    @_log 'password changed from', passwordChange.oldValue,
        'to', passwordChange.newValue
    return if passwordChange.newValue is @password
    if passwordChange.newValue
      @password = passwordChange.newValue
      @chat.setPassword @password
    else
      @_log 'password was cleared. Setting password back to', @password
      @_store 'password', @password

  _onServerDeviceChange: (serverChange) ->
    @_log 'device server changed from', serverChange.oldValue?.addr,
        serverChange.oldValue?.port, 'to', serverChange.newValue?.addr,
        serverChange.newValue?.port
    if serverChange.newValue
      @serverDevice = serverChange.newValue
      @_chat.remoteConnectionHandler.determineConnection @serverDevice
    else if @serverDevice
      @_store 'server_device', @serverDevice

  ##
  # Stops storing state items (channel, server, nick).
  # This is used when the client is resuming it's IRC state and doesn't want
  # to make redudant writes to storage.
  ##
  pause: ->
    @_paused = true

  resume: ->
    @_paused = false

  setAutostart: (opt_enabled) ->
    enabled = opt_enabled ? not @_autostart
    @_autostart = enabled
    @_store 'autostart', enabled
    return @_autostart

  finishedWalkthrough: ->
    @_store 'completed_walkthrough', true, 'local'

  nickChanged: (nick) ->
    return if @_nick is nick
    @_nick = nick
    @_store 'nick', nick

  channelJoined: (server, name, type='normal') ->
    return if @_isDuplicateChannel server, name
    channelObj = { server, name }
    channelObj.type = type unless type is 'normal'
    @_channels.push channelObj
    @_store 'channels', @_channels

  _isDuplicateChannel: (server, name) ->
    for chan in @_channels
      return true if chan.server is server and chan.name is name
    false

  serverJoined: (name, port) ->
    return if @_isDuplicateServer name, port
    @_servers.push { name, port }
    @_store 'servers', @_servers

  _isDuplicateServer: (name, port) ->
    for server, i in @_servers
      if server.name is name
        return true if server.port is port
        @_servers.splice i, 1
        break
    return false

  parted: (server, channel) ->
    if channel?
      @_channelParted server, channel
    else
      @_serverParted server

  _channelParted: (server, name) ->
    for channel, i in @_channels
      if channel.server is server and channel.name is name
        @_channels.splice i, 1
        break
    @_store 'channels', @_channels

  _serverParted: (name) ->
    for server, i in @_servers
      if server.name is name
        @_servers.splice i, 1
        break
    @_store 'servers', @_servers

  ignoredMessagesChanged: ->
    @_store 'ignored_messages', @_getIgnoredMessages()

  _getIgnoredMessages: ->
    @_chat.messageHandler.getIgnoredMessages()

  _store: (key, value, type='sync') ->
    return unless @shouldStore key
    @_log 'storing', key, '=>', value, 'to', type
    storageObj = {}
    storageObj[key] = value

    if type is 'sync'
      chrome.storage.sync.set storageObj
    else
      chrome.storage.local.set storageObj

  shouldStore: (key) ->
    return not (@_paused and key in Storage.STATE_ITEMS)

  getState: ->
    {
      ircStates: @_createIRCStates(),
      servers: @_servers,
      channels: @_channels,
      nick: @_nick,
      ignoredMessages: @_getIgnoredMessages()
    }

  _createIRCStates: ->
    ircStates = []
    for name, conn of @_chat.connections
      ircStates.push
        server: conn.name
        state: conn.irc.state
        channels: conn.irc.channels
        away: conn.irc.away
        nick: conn.irc.nick
    ircStates

  ##
  # Load initial items, such as whether to show the walkthrough.
  ##
  init: ->
    chrome.storage.local.get Storage.INITIAL_ITEMS_LOCAL, (state) =>
      @_initializeLocalItems state

      chrome.storage.sync.get Storage.INITIAL_ITEMS, (state) =>
        @_initializeSyncItems state

  _initializeSyncItems: (state) ->
    @_state = state
    @_restorePassword()
    @_loadServerDevice()
    @_autostart = state.autostart

  _initializeLocalItems: (state) ->
    @completedWalkthrough = state['completed_walkthrough']

  restoreSavedState: (opt_callback) ->
    chrome.storage.sync.get Storage.STATE_ITEMS, (savedState) =>
      @loadState savedState
      opt_callback?()

  loadState: (state) ->
    @_state = state
    @_restoreNick()
    @_restoreServers()
    @_restoreChannels()
    @_restoreIgnoredMessages()
    @_restoreIRCStates()
    @_markItemsAsLoaded Storage.STATE_ITEMS, state

  _restorePassword: ->
    @password = @_state.password
    if not @password
      @password = irc.util.randomName()
      @_log 'no password found, setting new password to', @password
      @_store 'password', @password
    else @_log 'password loaded from storage:', @password
    @_chat.setPassword @password
    @_chat.remoteConnectionHandler.determineConnection()

  _restoreServers: ->
    return unless servers = @_state.servers
    @_servers = servers
    for server in servers
      @_chat.connect server.name, server.port

  _restoreChannels: ->
    return unless channels = @_state.channels
    @_channels = channels
    for channel in channels
      conn = @_chat.connections[channel.server]
      continue unless conn
      if channel.type is 'private'
        @_chat.createPrivateMessageWindow conn, channel.name
      else
        @_chat.join conn, channel.name

  _restoreIgnoredMessages: ->
    return unless ignoredMessages = @_state['ignored_messages']
    @_log 'restoring ignored messages from storage:', ignoredMessages
    @_chat.messageHandler.setIgnoredMessages ignoredMessages

  _restoreNick: ->
    return unless (nick = @_state.nick) and typeof nick is 'string'
    @_nick = nick
    @_chat.setNick nick

  _restoreIRCStates: ->
    return unless ircStates = @_state.ircStates
    connectedServers = []
    for ircState in ircStates
      conn = @_chat.connections[ircState.server]
      connectedServers.push ircState.server
      @_setIRCState conn, ircState if conn
    @_disconnectServersWithNoState connectedServers

  _disconnectServersWithNoState: (connectedServers) ->
    for name, conn of @_chat.connections
      conn.irc.state = 'disconnected' unless name in connectedServers

  ##
  # Loads servers, channels and nick from the given IRC state.
  # The state has the following format:
  # { nick: string, channels: Array.<{sevrer, name}>,
  #     servers: Array.<{name, port}>, irc_state: object,
  #     server_device: { port: number, addr: string}, password: string }
  # @param {Object} ircState An object that represents the current state of an IRC
  #     client.
  ##
  _setIRCState: (conn, ircState) ->
    @_chat.onConnected conn if ircState.state is 'connected'
    conn.irc.state = ircState.state if ircState.state
    conn.irc.away = ircState.away if ircState.away
    conn.irc.channels = ircState.channels if ircState.channels
    conn.irc.nick = ircState.nick
    return unless ircState.channels
    for channelName, channelInfo of ircState.channels
      @_chat.onJoined conn, channelName
      nicks = (nick for norm, nick of channelInfo.names)
      @_chat.onNames { context: { server: conn.name, channel: channelName } }, nicks

  _loadServerDevice: ->
    @loadedServerDevice = true
    @serverDevice = @_state.server_device
    @_log 'no remote server found', @_state unless @serverDevice
    @_log 'loaded server device', @serverDevice if @serverDevice
    @_chat.remoteConnectionHandler.determineConnection()

  ##
  # Marks that a certain item has been loaded from storage.
  ##
  _markItemsAsLoaded: (items, state) ->
    for item in items
      this["#{item}Loaded"] = state[item]?

  becomeServerDevice: (connectionInfo) ->
    @serverDevice = { addr: connectionInfo.addr, port: connectionInfo.port }
    @_store 'server_device', @serverDevice

exports.Storage = Storage