exports = window.chat ?= {}

class SyncStorage

  @ITEMS = ['nick', 'servers', 'channels', 'password', 'remote_server']

  constructor: ->
    @_log = (type, msg...) => log this, type, msg...
    @_channels = []
    @_servers = []
    @_nick = undefined
    @_password = undefined
    @serverDevice = undefined
    chrome.storage.onChanged.addListener @_onChanged

  ##
  # Listen for storage changes.
  # If the password updated then change our own. If the password was cleared
  # then restore it.
  ##
  _onChanged: (changeMap, areaName) =>
    if changeMap.password
      @_onPasswordChange changeMap.password
    if changeMap.remote_server
      @_onRemoteServerChange changeMap.remote_server

  _onPasswordChange: (passwordChange) ->
    return if passwordChange.newValue is @_password
    if passwordChange.newValue
      @_log "another device changed the password from " +
          "#{passwordChange.oldValue} to #{passwordChange.newValue}"
      @_password = passwordChange.newValue
    else
      @_log "password was cleared. Setting password back to #{@_password}"
      @_store 'password', @_password

  _onRemoteServerChange: (serverChange) ->
    return unless serverChange.newValue.addr
    return if serverChange.newValue.addr is @serverDevice?.addr
    @_log "another device changed the remote server from " +
        "#{serverChange.oldValue} to #{serverChange.newValue}"
    @serverDevice = serverChange.newValue
    # TODO display a prompt asking if the user would like to use this other
    # connection
    @_chat.remoteConnection.connectToServer @serverDevice

  pause: ->
    @_paused = true

  resume: ->
    @_paused = false

  nickChanged: (nick) ->
    @_nick = nick
    @_store 'nick', nick

  channelJoined: (server, name) ->
    @_channels.push { server, name }
    @_store 'channels', @_channels

  serverJoined: (name, port) ->
    @_servers.push { name, port }
    @_store 'servers', @_servers

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

  _store: (key, value) ->
    return if @_paused
    storageObj = {}
    storageObj[key] = value
    chrome.storage.sync.set storageObj

  getState: (chat) ->
    @_chat = chat
    ircStates = @_createIRCStates()
    { ircStates, servers: @_servers, channels: @_channels, nick: @_nick }

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

  loadServerDevice: (chat) ->
    @_chat = chat
    chrome.storage.sync.get 'remote_server', (state) =>
      @_state = state
      @_loadRemoteConnection()

  restoreSavedState: (chat) ->
    @_chat = chat
    chrome.storage.sync.get SyncStorage.ITEMS, (savedState) =>
      @loadState chat, savedState

  loadState: (chat, state) ->
    @_state = state
    @_restoreNick()
    @_restoreServers()
    @_restoreChannels()
    @_restoreIRCStates()
    @_restorePassword()
    @_loadRemoteConnection()

  _restorePassword: ->
    @_password = @_state.password
    if not @_password
      @_password = irc.util.randomName()
      @_log 'no password found, setting new password to', @_password
      @_store 'password', @_password
    else @_log 'password loaded from storage:', @_password
    @_chat.setPassword @_password

  _restoreServers: ->
    return unless servers = @_state.servers
    @_servers = servers
    for server in servers
      @_chat.connect server.name, server.port

  _restoreChannels: ->
    return unless channels = @_state.channels
    @_channels = channels
    for channel in channels
      return unless conn = @_chat.connections[channel.server]
      @_chat.join conn, channel.name

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

  _loadRemoteConnection: ->
    @_log 'no remote server found', @_state unless @_state.remote_server
    @serverDevice = @_state.remote_server

  becomeRemoteServer: (connectionInfo) ->
    @serverDevice = { addr: connectionInfo.addr, port: connectionInfo.port }
    @_store 'remote_server', @serverDevice

exports.SyncStorage = SyncStorage