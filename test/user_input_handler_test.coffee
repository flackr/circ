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

  upArrow = ->
    keyDown 38

  downArrow = ->
    keyDown 40

  input =
    keydown: (cb) => inputKeyDown = cb
    focus: ->
    val: (text) ->
      if arguments.length == 0
        return val
      val = text
      onVal(text)

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

  it "uses the up arrow to show previous commands", ->
    type 'hi'
    type 'bye'

    upArrow()
    expect(onVal.mostRecentCall.args[0]).toBe 'bye'

    upArrow()
    expect(onVal.mostRecentCall.args[0]).toBe 'hi'

  it "does nothing when the up arrow is pressed and there is no more previous command", ->
    upArrow()
    expect(onVal).not.toHaveBeenCalled()

    val = 'current text'
    upArrow()
    expect(onVal).not.toHaveBeenCalled()

    type 'hi'
    upArrow()
    onVal.reset()

    upArrow()
    upArrow()
    expect(onVal).not.toHaveBeenCalled()

  it "uses the down arrow to move back toward current commands", ->
    type 'hi'
    type 'bye'
    upArrow()
    upArrow()
    downArrow()
    expect(onVal.mostRecentCall.args[0]).toBe 'bye'

  it "displas the current input value as most current previous command", ->
    type('hi')
    upArrow()
    downArrow()
    expect(onVal.mostRecentCall.args[0]).toBe ''

    type('hi')
    val = 'current text'
    upArrow()
    downArrow()
    expect(onVal.mostRecentCall.args[0]).toBe 'current text'

  it "does nothing when the down arrow is pressed but there is no more current command", ->
    downArrow()
    expect(onVal).not.toHaveBeenCalled()

    val = 'current text'
    downArrow()
    expect(onVal).not.toHaveBeenCalled()

    type('hi')
    upArrow()
    downArrow()
    onVal.reset()
    downArrow()
    downArrow()
    expect(onVal).not.toHaveBeenCalled()