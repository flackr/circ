describe 'A user command handler', ->
  win = onMode = onJoin = onMe = handler = undefined

  onMessage = jasmine.createSpy 'onMessage'
  context =
    determineWindow: -> win
    storage: { }
    displayMessage: ->

  getWindow = ->
    message: onMessage
    target: '#bash'
    conn:
      name: 'freenode.net'
      irc:
        state: 'connected'
        nick: 'ournick'
        channels: {}

  handle = (name, args...) ->
    handler.handle name, {}, args...

  beforeEach ->
    mocks.navigator.useMock()
    onMessage.reset()
    win = getWindow()
    handler = new chat.UserCommandHandler context
    onJoin = spyOn handler._handlers.join, 'run'
    onMe = spyOn handler._handlers.me, 'run'
    onMode = spyOn handler._handlers.mode, 'run'

  it "can handle valid user commands", ->
    for command in ['join', 'win']
      expect(handler.canHandle command).toBe true

  it "can't handle invalid user commands", ->
    commands = ['not_a_command', 'neitheristhis']
    for command in commands
      expect(handler.canHandle command).toBe false

  it 'runs commands that have valid args and can be run', ->
    handle 'join'
    expect(onJoin).toHaveBeenCalled()

  it "doesn't run commands that can't be run", ->
    win.conn.irc.state = 'disconnected'
    handle 'me', 'hi!'
    expect(onMe).not.toHaveBeenCalled()

  it "displays a help message when a command is run with invalid args", ->
    handle 'join', 'channel', 'extra_arg'
    expect(onJoin).not.toHaveBeenCalled()
    expect(onMessage.mostRecentCall.args[1]).toBe 'JOIN [channel], joins the ' +
        'channel, reconnects to the current channel if no channel is specified.'

  it "allows commands to extend eachother for easy aliasing", ->
    handle 'me', 'hey guy!'
    expect(onMe).toHaveBeenCalled()
    expect(handler._handlers.me.text).toBe '\u0001ACTION hey guy!\u0001'

  it "supports the mode command", ->
    handle 'mode'
    expect(onMode).toHaveBeenCalled()

    onMode.reset()
    handle 'mode', 'channel', 'invalid mode'
    expect(onMode).not.toHaveBeenCalled()

    handle 'mode', '+sm-v', 'nick1', 'nick2', 'nick3'
    expect(onMode).toHaveBeenCalled()

  it "supports the away command", ->
    onAway = spyOn handler._handlers.away, 'run'
    handle 'away'
    expect(onAway).toHaveBeenCalled()

    handle 'away', "I'm", "busy"
    expect(onAway).toHaveBeenCalled()

  it "supports the op command", ->
    onOp = spyOn handler._handlers.op, 'run'
    handle 'op', 'othernick'
    expect(onOp).toHaveBeenCalled()

  it "only runs /join-server when online", ->
    onJoinServer = spyOn handler._handlers['join-server'], 'run'
    handle 'join-server'
    expect(onJoinServer).toHaveBeenCalled()

    mocks.navigator.goOffline()
    handler._handlers['join-server'].run.reset()
    handle 'join-server'
    expect(onJoinServer).not.toHaveBeenCalled()

  describe "handles the command autostart", ->

    beforeEach ->
      context.storage.setAutostart = jasmine.createSpy 'setAutostart'

    it "enables autostart with 'autostart on'", ->
      handle 'autostart', 'on'
      expect(context.storage.setAutostart).toHaveBeenCalledWith true

    it "disables autostart with 'autostart off'", ->
      handle 'autostart', 'off'
      expect(context.storage.setAutostart).toHaveBeenCalledWith false

    it "toggles autostart with 'autostart'", ->
      handle 'autostart'
      expect(context.storage.setAutostart).toHaveBeenCalledWith undefined

    it "doesn't accept invalid input", ->
      handle 'autostart', 'offf'
      handle 'autostart', 'bob'
      expect(context.storage.setAutostart).not.toHaveBeenCalled()

      handle 'autostart', 'oFf'
      expect(context.storage.setAutostart).toHaveBeenCalled()