exports = window.chat ?= {}

# TODO sort first by op status, then name
class NickList extends chat.HTMLList

  add: (nick) ->
    i = @_getClosestIndex nick
    @insert i, nick

  _getClosestIndex: (nick) ->
    for name, i in @nodeNames
      return i if name > nick
    @nodeNames.length

exports.NickList = NickList