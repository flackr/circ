describe 'A channel list', ->
  dom = cl = undefined

  item = (index) ->
    return $('li', dom).last() if index is -1
    $ $('li', dom)[index]

  items = ->
    $('li', dom)

  textOfItem = (index) ->
    item(index).children().text()

  beforeEach ->
    dom = $ "<ul id='channels' style='display: hidden'>"
    $('body').append dom
    cl = new chat.ChannelList()

  afterEach ->
    dom.remove()

  it 'can have a server item added', ->
    cl.add 'freenode'
    expect(items().length).toBe 1

  it 'can have a channel item added', ->
    cl.add 'freenode', '#bash'
    expect(items().length).toBe 1

  it 'can have a channel item removed', ->
    cl.add 'freenode', '#bash'
    cl.remove 'freenode', '#bash'
    expect(items().length).toBe 0

  it 'can have a server item removed', ->
    cl.add 'freenode'
    cl.remove 'freenode'
    expect(items().length).toBe 0

  it 'shows items as initially disconnected', ->
    cl.add 'freenode'
    expect(textOfItem 0).toBe '(freenode)'

  it 'shows items as connected on connect()', ->
    cl.add 'freenode'
    cl.connect 'freenode'
    expect(textOfItem 0).toBe 'freenode'

  it 'displays channel items by their channel name', ->
    cl.add 'freenode', '#bash'
    expect(textOfItem 0).toBe '(#bash)'

  it "indents channel items", ->
    cl.add 'freenode', '#bash'
    expect(item 0).toHaveClass 'indent'

  it "marks the last channel item", ->
    cl.add 'freenode'
    cl.add 'freenode', '#bash'
    expect(item 1).toHaveClass 'last'

    cl.add 'freenode', '#awesome'
    expect(item 1).not.toHaveClass 'last'
    expect(item 2).toHaveClass 'last'

    cl.remove 'freenode', '#awesome'
    expect(item 1).toHaveClass 'last'

  it "marks the last channel item, even with multiple servers and matching channel names", ->
    cl.add 'irc.freenode'
    cl.add 'irc.freenode', '#bash'
    cl.add 'irc.dalnet'
    cl.add 'irc.dalnet', '#bash'
    cl.add 'irc.dalnet', '#bash2'

    cl.remove 'irc.dalnet', '#bash2'
    expect(item -1).toHaveClass 'last'

    cl.add 'irc.dalnet', '#bash2'
    cl.insert 2, 'irc.freenode', '#bash2'
    expect(item 2).toHaveClass 'last'

  it "supports multiple servers and channels", ->
    cl.add 'freenode'
    cl.add 'freenode', '#bash'
    cl.add 'freenode', '#awesome'
    cl.add 'dalnet'
    cl.add 'dalnet', '#cool'
    expect(items().length).toBe 5

    expect(item 2).toHaveClass 'last'
    expect(item 4).toHaveClass 'last'

  it "can mark an item as selected", ->
    cl.add 'freenode'
    cl.select 'freenode'
    expect(item 0).toHaveClass 'selected'

  it "can have only one item selected at a time", ->
    cl.add 'freenode'
    cl.add 'freenode', '#bash'
    cl.select 'freenode'
    cl.select 'freenode', '#bash'
    expect(item 0).not.toHaveClass 'selected'
    expect(item 1).toHaveClass 'selected'

  it "can have an item inserted at a specific index", ->
    cl.add 'freenode'
    cl.add 'freenode', '#bash'
    cl.insert 1, 'freenode', '#awesome'
    expect(items().length).toBe 3
    expect(textOfItem 1).toBe '(#awesome)'