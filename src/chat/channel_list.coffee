exports = window.chat ?= {}

##
# A list of servers and channels to which the user is connected.
##
class ChannelList extends EventEmitter
  constructor: ->
    super
    @$surface = $ '#rooms-container .rooms'
    @roomsByServer = {}

  select: (server, channel) ->
    @_removeLastSelected()
    @_addClass server, channel, 'selected'
    @_removeClass server, channel, 'activity'
    @_removeClass server, channel, 'mention'

  _removeLastSelected: ->
    $('.room.selected', @$surface)?.removeClass 'selected'

  activity: (server, opt_channel) ->
    @_addClass server, opt_channel, 'activity'

  mention: (server, opt_channel) ->
    @_addClass server, opt_channel, 'mention'

  remove: (server, opt_channel) ->
    if opt_channel?
      @roomsByServer[server].channels.remove opt_channel
    else
      @roomsByServer[server].html.remove()
      delete @roomsByServer[server]

  insertChannel: (i, server, channel) ->
    @roomsByServer[server].channels.insert i, channel
    @disconnect server, channel

  addServer: (serverName) ->
    html = @_createServerHTML serverName
    server = $ '.server', html
    channels = @_createChannelList html
    @_handleMouseEvents serverName, server, channels
    @roomsByServer[serverName] = { html, server, channels }
    @disconnect serverName

  _createServerHTML: (serverName) ->
    html = $('#templates .server-channels').clone()
    $('.server .content-item', html).text serverName
    @$surface.append html
    html

  _createChannelList: (html) ->
    channelTemplate = $ '#templates .channel'
    channelList = new chat.HTMLList $('.channels', html), channelTemplate
    channelList

  _handleMouseEvents: (serverName, server, channels) ->
    server.mousedown => @_handleClick serverName
    channels.on 'clicked', (channelName) =>
        @_handleClick serverName, channelName

  disconnect: (server, opt_channel) ->
    @_addClass server, opt_channel, 'disconnected'

  connect: (server, opt_channel) ->
    @_removeClass server, opt_channel, 'disconnected'

  _addClass: (server, channel, c) ->
    if channel?
      @roomsByServer[server].channels.addClass channel, c
    else
      @roomsByServer[server].server.addClass c

  _removeClass: (server, channel, c) ->
    if channel?
      @roomsByServer[server].channels.removeClass channel, c
    else
      @roomsByServer[server].server.removeClass c

  _handleClick: (server, channel) =>
    @emit 'clicked', server, channel

exports.ChannelList = ChannelList