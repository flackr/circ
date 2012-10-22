exports = window.chat ?= {}

# TODO sort first by op status, then name
class NickList extends chat.HTMLList

  constructor: (surface) ->
    super surface, $ '#templates .nick'

  add: (nick) ->
    i = @_getClosestIndex nick
    @insert i, nick

  _getClosestIndex: (nick) ->
    nick = nick.toLowerCase()
    for name, i in @nodeNames
      return i if name.toLowerCase() > nick
    @nodeNames.length

exports.NickList = NickList