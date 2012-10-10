exports = window.chat ?= {}

# TODO show servers as well as channels
class ChannelList extends chat.HTMLList
  constructor: ->
    super $ '#channels'
    @lastSelected = undefined

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
    prev = @getPrevious id
    @removeClass prev, 'last' if prev

  _isLastChannel: (id) ->
    return false unless id and @_isChannel id
    nextNode = @getNext id
    return not nextNode or not @_isChannel nextNode

  _isChannel: (id) ->
    return id.indexOf ' ' >= 0

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