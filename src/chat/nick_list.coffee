exports = window.chat ?= {}

# TODO sort first by op status, then name
class NickList
  constructor: ->
    @$nickList = $ "#nicks"

  addInOrder: (nicks) ->
    for nick in nicks
      @$nickList.append $ "<li>#{nick}</li>"

  add: (nick) ->
    # TODO binary search
    htmlNick = $ "<li>#{nick}</li>"
    for nickLi in $ 'li', @$nickList
      if $(nickLi).text() > nick
        htmlNick.insertBefore $(nickLi)
        return
    @$nickList.append htmlNick

  rename: (from, to) ->
    @remove from
    @add to

  remove: (nick) ->
    # TODO binary search
    for nickLi in $ 'li', @$nickList
      if irc.util.nicksEqual $(nickLi).text(), nick
        $(nickLi).remove()

  clear: ->
    @$nickList.empty()

exports.NickList = NickList