exports = window.chat ?= {}

# TODO show servers as well as channels
class ChannelList extends chat.HTMLList
  constructor: ->
    super $ '#channels'
    @lastSelected = undefined

  select: (channel) ->
    @removeClass @lastSelected if @lastSelected?
    @lastSelected = channel
    @addClass channel, 'selected'

  disconnect: (channel) ->
    #TODO color channel / server different when disconnected

  reconnect: (channel) ->
    #TODO color channel / server different when connected

exports.ChannelList = ChannelList