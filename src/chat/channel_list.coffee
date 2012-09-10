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

  selectNext: ->
    # TODO implement - used with ALT down/right

  selectPrevious: ->
    # TODO implement - used with ALT up/left

  add: (chan) ->
    super chan
    @disconnect(chan)

  disconnect: (channel) ->
    @rename channel, '(' + channel + ')'

  connect: (channel) ->
    @rename channel, channel

exports.ChannelList = ChannelList