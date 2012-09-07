exports = window.chat ?= {}

class HTMLList extends EventEmitter
  constructor: (@$list, @ordered=false) ->
    super

  add: (names...) ->
    for name in names
      if @ordered
        @_addOrdered name
      else
        @_addNode name

  _addOrdered: (name) ->
    # TODO binary search
    for nameLi in $ 'li', @$list
      if $(nameLi).text() > name
        htmlify(name).insertBefore $(nameLi)
        return
    @_addNode name

  _addNode: (name) ->
    html = htmlify name
    $(html).mousedown((e) => @_handleClick(e))
    @$list.append html

  _handleClick: (e) ->
    name = $(e.srcElement).text()
    @emit 'clicked', name

  addClass: (name, c) ->
    node = @_find(name)
    @_addClassToNode node, c if node

  removeClass: (name) ->
    node = @_find(name)
    @_removeClassFromNode node if node

  clearClasses: ->
    for node in $ 'li', @$list
      @_removeClassFromNode node

  _addClassToNode: (node, c) ->
    $(node).addClass(c)

  _removeClassFromNode: (node) ->
    $(node).removeClass()

  rename: (from, to) ->
    @remove from
    @add to

  remove: (name) ->
    @_find(name)?.remove()

  _find: (name) ->
    # TODO binary search if ordered
    for nameLi in $ 'li', @$list
      if irc.util.nicksEqual $(nameLi).text(), name
        return $(nameLi)
    undefined

  clear: ->
    @$list.empty()

htmlify = (name) ->
    $ "<li>#{name}</li>"

exports.HTMLList = HTMLList