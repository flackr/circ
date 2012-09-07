exports = window.chat ?= {}

# TODO sort first by op status, then name
class NickList extends chat.HTMLList
  constructor: (html) ->
    super html, true

exports.NickList = NickList