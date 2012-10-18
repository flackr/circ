describe 'A channel list', ->
  dom = cl = undefined

  item = (index) ->
    return items().last() if index is -1
    $ items()[index]

  items = ->
    $ '#rooms-container .rooms .room'

  textOfItem = (index) ->
    $('.content-item', item(index)).text()

  beforeEach ->
    mocks.dom.setUp()
    cl = new chat.ChannelList()
    spyOn cl, 'emit'

  afterEach ->
    mocks.dom.tearDown()

  it 'can have a server item added', ->
    cl.addServer 'freenode'
    expect(items().length).toBe 1

  it 'displays servers by their name', ->
    cl.addServer 'freenode'
    expect(textOfItem 0).toBe 'freenode'

  it 'can have a channel item inserted', ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    cl.insertChannel 0, 'freenode', '#awesome'
    expect(items().length).toBe 3
    expect(textOfItem 1).toBe '#awesome'

  it 'displays channel items by their channel name', ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    expect(textOfItem 1).toBe '#bash'

  it 'can have a channel item removed', ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    cl.remove 'freenode', '#bash'
    expect(items().length).toBe 1

  it 'can have a server item removed', ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    cl.remove 'freenode'
    expect(items().length).toBe 0

  it 'shows items as initially disconnected', ->
    cl.addServer 'freenode'
    expect(item 0).toHaveClass 'disconnected'

  it 'shows items as connected on connect()', ->
    cl.addServer 'freenode'
    cl.connect 'freenode'
    expect(item 0).not.toHaveClass 'disconnected'

  it "supports multiple servers and channels", ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    cl.insertChannel 1, 'freenode', '#awesome'
    cl.addServer 'dalnet'
    cl.insertChannel 0, 'dalnet', '#cool'
    expect(items().length).toBe 5

  it "can mark an item as selected", ->
    cl.addServer 'freenode'
    cl.select 'freenode'
    expect(item 0).toHaveClass 'selected'

  it "can have only one item selected at a time", ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    cl.select 'freenode'
    cl.select 'freenode', '#bash'
    expect(item 0).not.toHaveClass 'selected'
    expect(item 1).toHaveClass 'selected'

  it "can mark an item as having activity", ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    cl.activity 'freenode', '#bash'
    expect(item 1).toHaveClass 'activity'

  it "can mark an item as having a nick mention", ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    cl.mention 'freenode', '#bash'
    expect(item 1).toHaveClass 'mention'

  it "can mark an item as having a nick mention and activity", ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    cl.mention 'freenode', '#bash'
    cl.activity 'freenode', '#bash'
    expect(item 1).toHaveClass 'mention'
    expect(item 1).toHaveClass 'activity'

  it "selecting a channel clears activity and mention", ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    cl.mention 'freenode', '#bash'
    cl.activity 'freenode', '#bash'
    cl.select 'freenode', '#bash'
    expect(item 1).toHaveClass 'selected'
    expect(item 1).not.toHaveClass 'mention'
    expect(item 1).not.toHaveClass 'activity'

  it "emits a clicked event when a channel is clicked", ->
    cl.addServer 'freenode'
    cl.insertChannel 0, 'freenode', '#bash'
    item(1).mousedown()
    expect(cl.emit).toHaveBeenCalledWith 'clicked', 'freenode', '#bash'

  it "emits a clicked event when a server is clicked", ->
    cl.addServer 'freenode'
    item(0).mousedown()
    expect(cl.emit).toHaveBeenCalledWith 'clicked', 'freenode', undefined