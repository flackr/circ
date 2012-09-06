exports = window.chat ?= {}

class HTMLList
  constructor: (@$list, @ordered=false) ->

  add: (names...) ->
    for name in names
      if @ordered
        @_addOrdered name
      else
        @$list.append htmlify name

  _addOrdered: (name) ->
    # TODO binary search
    for nameLi in $ 'li', @$list
      if $(nameLi).text() > name
        htmlify(name).insertBefore $(nameLi)
        return
    @$list.append htmlify name

  rename: (from, to) ->
    @remove from
    @add to

  remove: (name) ->
    # TODO binary search if ordered
    for nameLi in $ 'li', @$list
      if irc.util.nicksEqual $(nameLi).text(), name
        $(nameLi).remove()
        return

  clear: ->
    @$list.empty()

htmlify = (name) ->
    $ "<li>#{name}</li>"

exports.HTMLList = HTMLList