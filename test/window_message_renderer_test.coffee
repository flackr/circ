describe "A window message renderer", ->
  surface = renderer = undefined

  message = (num) ->
    return $('div.message', surface)[num]

  beforeEach ->
    surface = $ '<div>'
    renderer = new chat.window.MessageRenderer surface

  afterEach ->
    surface.remove()

  it "displayes messages to the user", ->
    renderer.message 'bob', 'hi'
    expect(message(0).text).toBe 'hi'
    expect(message(0).from).toBe 'bob'