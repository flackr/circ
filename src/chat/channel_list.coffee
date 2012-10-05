exports = window.chat ?= {}

# TODO show servers as well as channels
class ChannelList extends chat.HTMLList
  constructor: ->
    super $ '#channels'
    @lastSelected = undefined
    @_lastChannelForServer = {}

  select: (server, channel) ->
    @removeClass @_lastSelected, 'selected' if @_lastSelected?
    currentWindow = @_getID server, channel
    @_lastSelected = currentWindow
    @removeClass currentWindow, 'activity'
    @removeClass currentWindow, 'mention'
    @addClass currentWindow, 'selected'

  activity: (server, channel) ->
    @addClass @_getID(server, channel), 'activity'

  mention: (server, channel) ->
    @addClass @_getID(server, channel), 'mention'

  remove: (server, chan) ->
    id = @_getID server, chan
    @_lastChannelForServer[server] is id
    prev = @getPrevious id
    super id
    @_styleLastChannel server, prev

  insert: (i, server, chan) ->
    super i, @_getID server, chan
    @_formatNode server, chan

  add: (server, chan) ->
    super @_getID server, chan
    @_formatNode server, chan

  _formatNode: (server, chan) ->
    @disconnect(server, chan)
    if chan?
      id = @_getID server, chan
      @addClass id, 'indent'
      @_styleLastChannel server, id

  _styleLastChannel: (server, id) ->
    return unless @_isLastChannel id
    @addClass id, 'last'
    prev = @_lastChannelForServer[server]
    @removeClass prev, 'last' if prev
    @_lastChannelForServer[server] = id

  _isLastChannel: (id) ->
    return false unless id
    nextNode = @getNext id
    not nextNode or not @hasClass nextNode, 'indent'

  disconnect: (server, channel) ->
    @rename @_getID(server, channel), @_getDisconnectedName server, channel

  connect: (server, channel) ->
    @rename @_getID(server, channel), channel ? server

  _getDisconnectedName: (server, channel) ->
    name = channel ? server
    return '(' + name + ')'

  _getID: (server, channel) ->
    if not channel?
      return server
    return server + ' ' + channel

  _handleClick: (node) ->
    @emit 'clicked', node.name.split(' ')...

exports.ChannelList = ChannelList