exports = window.chat ?= {}

class HTMLList extends EventEmitter
  constructor: (@$list, @ordered=false) ->
    @nodes = {}
    super

  add: (names...) ->
    for name in names
      continue if name of @nodes
      if @ordered
        @_addOrdered name
      else
        node = @_createNode name
        @$list.append node.html

  insert: (index, name) ->
    return if name of @nodes
    node = @_createNode name
    for nameLi, i in $ 'li', @$list
      if i >= index
        node.html.insertBefore $(nameLi)
        return
    @$list.append node.html

  getNext: (nodeName) ->
    returnNext = false
    for li, i in $ 'li', @$list
      if returnNext
        return @getNodeByText $(li).children().text(), $(li)
      returnNext = @nodes[nodeName]?.content.text() is $(li).children().text()
    return undefined

  getNodeByText: (text, html) ->
    for name, node of @nodes
      return name if node.content.text() is text

  remove: (name) ->
    if node = @nodes[name]
      node.html.remove()
      delete @nodes[name]

  clear: ->
    @nodes = {}
    @$list.empty()

  addClass: (name, c) ->
    @nodes[name]?.html.addClass(c)

  removeClass: (name, c) ->
    @nodes[name]?.html.removeClass(c)

  clearClasses: ->
    for name of @nodes
      @removeClass node

  hasClass: (nodeName, c) ->
    return @nodes[nodeName]?.html.hasClass c

  replace: (oldName, newName) ->
    if @nodes[oldName]?
      @remove oldName
      @add newName

  rename: (name, text) ->
    @nodes[name]?.content.text(text)

  _addOrdered: (name) ->
    # TODO binary search
    for nameLi in $ 'li', @$list
      if $(nameLi).children().text() > name
        node = @_createNode name
        node.html.insertBefore $(nameLi)
        return
    node = @_createNode name
    @$list.append node.html

  _createNode: (name) ->
    node = {html: htmlify(name), name: name}
    node.content = node.html.children()
    node.html.mousedown( => @_handleClick(node))
    @nodes[name] = node

  _handleClick: (node) ->
    @emit 'clicked', node.name

htmlify = (name) ->
    $ "<li><div>#{name}</div></li>"

exports.HTMLList = HTMLList