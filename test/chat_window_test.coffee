describe "A chat window", ->

  beforeEach ->
    mocks.dom.setUp()

  afterEach ->
    mocks.dom.tearDown()

  it "doens't display the 'nicks' title when not in any channel", ->
    win = new chat.Window 'name'
    win.attach()
    expect($ '#rooms-and-nicks').toHaveClass 'no-nicks'