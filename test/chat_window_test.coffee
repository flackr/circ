describe "A chat window", ->

  beforeEach ->
    mocks.dom.setUp()

  afterEach ->
    mocks.dom.tearDown()

  it "doens't display the 'nicks' title when not in any channel", ->
    win = new chat.Window 'name'
    win.attach()
    expect($ '#rooms-and-nicks').toHaveClass 'no-nicks'

  it "clears all messages when the clear command is issued", ->
    win = new chat.Window 'name'
    win.attach()
    win.rawHTML('<p>Some text</p>')
    win.clear()
    expect(win.$messages.html()).toBe('')
