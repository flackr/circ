exports = window.chat ?= {}

class SyncStorage

  @ITEMS = ['nicks', 'servers', 'channels']

  constructor: ->
    @_channels = []
    @_servers = []
    @_nicks = []

  nickChanged: (server, name) ->
    for nick, i in @_nicks
      if server is nick.server
        @_nicks[i].name = name
        @_store 'nicks', @_nicks
        return
    @_nicks.push { server, name }
    @_store 'nicks', @_nicks

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

  getState: ->
    { servers: @_servers, channels: @_channels, nicks: @_nicks }

  restoreSavedState: (chat) ->
    @_chat = chat
    chrome.storage.sync.get SyncStorage.ITEMS, (savedState) =>
      @loadState chat, savedState

  loadState: (chat, state) ->
    @_state = state
    @_restoreNick()
    @_restoreServers()
    @_restoreChannels()

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
    return unless (nicks = @_state.nicks) and Array.isArray nicks
    for nick in nicks
      @_chat.setNick nick.server, nick.name

exports.SyncStorage = SyncStorage