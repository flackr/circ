exports = window.chat ?= {}

class SyncStorage

  @ITEMS = ['nick', 'servers', 'channels']

  constructor: ->
    @_channels = []
    @_servers = []
    @_nick = ''

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

  _restoreServers: ->
    return unless (servers = @_state.servers) and Array.isArray servers
    for server in servers
      @_chat.connect server.name, server.port

  _restoreChannels: ->
    return unless (channels = @_state.channels) and Array.isArray channels
    for channel in channels
      return unless conn = @_chat.connections[channel.server]
      @_chat.join conn, channel.name

  _restoreNick: ->
    return unless (nick = @_state.nick) and typeof nick is 'string'
    @_chat.setNick nick

  _restoreIRCStates: ->
    return unless (ircStates = @_state.ircStates) and Array.isArray ircStates
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
    @_chat.onConnected conn
    conn.irc.state = ircState.state
    conn.irc.away = ircState.away
    conn.irc.channels = ircState.channels
    conn.irc.nick = ircState.nick
    for channelName, channelInfo of ircState.channels
      @_chat.onJoined conn, channelName
      nicks = (nick for norm, nick of channelInfo.nicks)
      @_chat.onNames { context: { server: conn.name, channel: channelName } }, nicks

exports.SyncStorage = SyncStorage