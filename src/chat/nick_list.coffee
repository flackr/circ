exports = window.chat ?= {}

# TODO sort first by op status, then name
class NickList extends chat.HTMLList
  constructor: ->
    super $("#nicks"), true

exports.NickList = NickList