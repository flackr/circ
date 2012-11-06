exports = window.chat ?= {}

##
# A list of elements that can be manipulated.
##
class HTMLList extends EventEmitter
  constructor: (@$list, @$template) ->
    @nodes = {}
    @nodeNames = []
    super

  add: (name) ->
    @insert @nodeNames.length, name

  insert: (index, name) ->
    return if name of @nodes
    if index < 0 or index > @nodeNames.length
      throw "invalid index: #{index}/#{@nodeNames.length}"

    newNode = @_createNode name
    @_insertHTML index, newNode
    @nodes[name] = newNode
    @nodeNames.splice index, 0, name

  _insertHTML: (index, newNode) ->
    nextNode = @get index
    if nextNode
      newNode.html.insertBefore nextNode.html
    else
      @$list.append newNode.html

  get: (index) ->
    @nodes[@nodeNames[index]]

  getPrevious: (nodeName) ->
    i = @nodeNames.indexOf nodeName
    @nodeNames[i - 1]

  getNext: (nodeName) ->
    i = @nodeNames.indexOf nodeName
    @nodeNames[i + 1]

  remove: (name) ->
    if node = @nodes[name]
      node.html.remove()
      delete @nodes[name]
      removeFromArray @nodeNames, name

  clear: ->
    @nodes = {}
    @nodeNames = []
    @$list.empty()

  addClass: (name, c) ->
    @nodes[name]?.html.addClass(c)

  removeClass: (name, c) ->
    @nodes[name]?.html.removeClass(c)

  hasClass: (nodeName, c) ->
    return @nodes[nodeName]?.html.hasClass c

  rename: (name, text) ->
    @nodes[name]?.content.text(text)

  _createNode: (name) ->
    node = {html: @_htmlify(name), name: name}
    node.content = $('.content-item', node.html)
    node.html.mousedown => @_handleClick node
    node

  _handleClick: (node) ->
    @emit 'clicked', node.name

  _htmlify: (name) ->
    html = @$template.clone()
    $('.content-item', html).text name
    html

exports.HTMLList = HTMLList