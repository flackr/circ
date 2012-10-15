describe "A chat window", ->

  beforeEach ->
    mocks.dom.setUp()

  afterEach ->
    mocks.dom.tearDown()

  it 'should not display nicks by default', ->
    win = new chat.Window 'name'
    win.attach()
    expect($ '#rooms-and-nicks').toHaveClass 'no-nicks'