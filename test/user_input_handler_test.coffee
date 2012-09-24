describe 'A user input handler', ->
  handler = altHeld = val = inputKeyDown = windowKeyDown =  undefined

  onVal = jasmine.createSpy 'onVal'

  keyDown = (code) ->
    e =
      which: code
      altKey: altHeld
      preventDefault: ->
    windowKeyDown e
    inputKeyDown e

  type = (text) ->
    val = text
    keyDown 13

  input =
    keydown: (cb) => inputKeyDown = cb
    focus: ->
    val: ->
      if arguments.length == 0
        return val
      onVal()

  window =
    keydown: (cb) => windowKeyDown = cb

  context = { currentWindow: { target: '#bash', conn: { name: 'freenode.net' } } }

  beforeEach ->
    handler = new UserInputHandler input, window
    handler.setContext context
    spyOn handler, 'emit'
    altHeld = false
    onVal.reset()

  it "switches to the given window on 'alt-[0-9]'", ->
    altHeld = true
    keyDown 48 # 0
    expect(handler.emit).toHaveBeenCalledWith 'switch_window', 0

    keyDown 57 # 9
    expect(handler.emit).toHaveBeenCalledWith 'switch_window', 9

  it "doesn't switch windows when alt isn't held", ->
    keyDown 48 # 0
    keyDown 57 # 9
    expect(handler.emit).not.toHaveBeenCalled()

  it "sends a say command when text is entered", ->
    type 'hello world!'
    expect(handler.emit).toHaveBeenCalledWith 'command', jasmine.any Object

    e = handler.emit.mostRecentCall.args[1]
    expect(e.type).toBe 'command'
    expect(e.name).toBe 'say'
    expect(e.context).toEqual { server: 'freenode.net', channel: '#bash' }
    expect(e.args).toEqual 'hello world!'.split ' '

  it "sends the given command when a command is entered", ->
    type '/kick sugarman for spamming /dance'
    expect(handler.emit).toHaveBeenCalledWith 'command', jasmine.any Object

    e = handler.emit.mostRecentCall.args[1]
    expect(e.type).toBe 'command'
    expect(e.name).toBe 'kick'
    expect(e.context).toEqual { server: 'freenode.net', channel: '#bash' }
    expect(e.args).toEqual 'sugarman for spamming /dance'.split ' '