exports = window.chat ?= {}

# TODO show servers as well as channels
class ChannelList extends chat.HTMLList
  constructor: ->
    super $ '#channels'
    @lastSelected = undefined

  select: (server, channel) ->
    @removeClass @lastSelected, 'selected' if @lastSelected?
    @lastSelected = @_getID server, channel
    @addClass @_getID(server, channel), 'selected'

  remove: (server, chan) ->
    super @_getID server, chan

  insert: (i, server, chan) ->
    super i, @_getID server, chan
    @_formatNode server,chan

  add: (server, chan) ->
    super @_getID server, chan
    @_formatNode server,chan

  _formatNode: (server, chan) ->
    @disconnect(server, chan)
    if chan?
      @addClass @_getID(server, chan), 'indent'

  disconnect: (server, channel) ->
    @rename @_getID(server, channel), @_getDisconnectedName server, channel

  connect: (server, channel) ->
    @rename @_getID(server, channel), @_getName server, channel

  _getName: (server, channel) ->
    if channel?
      return '- ' + channel
    return server

  _getDisconnectedName: (server, channel) ->
    if channel?
      return '- (' + channel + ')'
    return '(' + server + ')'

  _getID: (server, channel) ->
    if not channel?
      return server
    return server + ' ' + channel

  _handleClick: (node) ->
    @emit 'clicked', node.name.split(' ')...

exports.ChannelList = ChannelList