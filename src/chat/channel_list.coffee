exports = window.chat ?= {}

# TODO show servers as well as channels
class ChannelList extends chat.HTMLList
  constructor: ->
    super $ '#channels'

  leave: (channel) ->
    #TODO color channel / server different when disconnected

exports.ChannelList = ChannelList