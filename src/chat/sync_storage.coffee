exports = window.chat ?= {}

class SyncStorage

  @ITEMS = ['nick', 'servers', 'channels']

  constructor: ->
    @_channels = []
    @_servers = []

  nickChanged: (newNick) ->
    @_store 'nick', newNick

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

  restoreState: (chat) ->
    @_chat = chat
    chrome.storage.sync.get SyncStorage.ITEMS, (prevState) =>
      @_prevState = prevState
      @_restoreServers()
      @_restoreChannels()
      @_restoreNick()

  _restoreServers: ->
    return unless servers = @_prevState.servers
    for server in servers
      @_chat.connect server.name, server.port

  _restoreChannels: ->
    return unless channels = @_prevState.channels
    for channel in channels
      return unless conn = @_chat.connections[channel.server]
      @_chat.join conn, channel.name

  _restoreNick: ->
    return unless nick = @_prevState.nick
    @_chat.previousNick = nick
    @_chat.updateStatus()

exports.SyncStorage = SyncStorage