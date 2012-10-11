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

  tab = ->
    keyDown 9

  ctrl = ->
    keyDown 17

  numlock = ->
    keyDown 144

  space = ->
    keyDown 32
    val += ' '

  cursor = (pos) ->
    handler._getCursorPosition = -> pos

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

  names = {bill: 'bill', sally: 'sally', bob: 'bob', joe: 'Joe'}

  context = currentWindow:
    target: '#bash'
    conn:
      name: 'freenode.net'
      irc:
        channels: {}

  beforeEach ->
    handler = new UserInputHandler input, window
    context.currentWindow.conn.irc.channels['#bash'] = {names}
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

  describe 'auto-complete', ->

    it "completes the current word and adds a colon + space after if it starts the phrase", ->
      val = 'b'
      cursor 1
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'bill: '

    it "completes the current word when the cursor is at the begining of the input", ->
      val = 'b'
      cursor 0
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'bill: '

    it "completes the current word and adds a space after if it doesn't start the phrase", ->
      val = ' b'
      cursor 2
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe ' bill '

    it "completes the current word when the phrase ends with a space", ->
      val = 'b '
      cursor 1
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'bill:  '

    it "completes the current word when the cursor is in the middle of a word", ->
      val = 'sis cool'
      cursor 1
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'sally: is cool'

    it "completes the current word, even when the cursor moves", ->
      val = 'well, s is great'
      cursor 7
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'well, sally  is great'

    it "completes the current word, even when there is space between the cursor and the word", ->
      val = 'well, sal         is great'
      cursor 15
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'well, sally          is great'

    it "goes to next completion on tab", ->
      val = 'b'
      cursor 0
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'bill: '
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'bob: '
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'bill: '

    it "stops cycling possible completions only when input is entered", ->
      val = 'b'
      cursor 0
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'bill: '
      ctrl()
      numlock()
      tab()
      cursor 6
      expect(onVal.mostRecentCall.args[0]).toBe 'bob: '
      space()
      tab()
      cursor 5
      expect(onVal.mostRecentCall.args[0]).toBe 'bob:  '

    it "does nothing when no completion candidates match", ->
      val = 'zack'
      cursor 0
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'zack'

    it "adds ': ' even when the the full nick is typed out when tab is pressed", ->
      val = 'bill'
      cursor 4
      tab()
      expect(onVal.mostRecentCall.args[0]).toBe 'bill: '

  describe 'input stack', ->

    upArrow = ->
      keyDown 38

    downArrow = ->
      keyDown 40

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

    it "displays the current input value as most current previous command", ->
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
