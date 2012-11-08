describe 'A user command handler', ->
  win = onMode = onJoin = onMe = handler = undefined

  onMessage = jasmine.createSpy 'onMessage'
  context =
    determineWindow: -> win
    syncStorage: { }

  getWindow = ->
    message: onMessage
    target: '#bash'
    conn:
      name: 'freenode.net'
      irc:
        state: 'connected'
        nick: 'ournick'
        channels: {}

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
    handler.handle 'join', {}
    expect(onJoin).toHaveBeenCalled()

  it "doesn't run commands that can't be run", ->
    win.conn.irc.state = 'disconnected'
    handler.handle 'me', {}, 'hi!'
    expect(onMe).not.toHaveBeenCalled()

  it "displays a help message when a command is run with invalid args", ->
    handler.handle 'join', {}, 'channel', 'extra_arg'
    expect(onJoin).not.toHaveBeenCalled()
    expect(onMessage.mostRecentCall.args[1]).toBe 'JOIN [channel], joins the channel, ' +
        'the current channel is used by default.'

  it "allows commands to extend eachother for easy aliasing", ->
    handler.handle 'me', {}, 'hey guy!'
    expect(onMe).toHaveBeenCalled()
    expect(handler._handlers.me.text).toBe '\u0001ACTION hey guy!\u0001'

  it "supports the mode command", ->
    handler.handle 'mode', {}
    expect(onMode).not.toHaveBeenCalled()

  it "supports the away command", ->
    onAway = spyOn handler._handlers.away, 'run'
    handler.handle 'away', {}
    expect(onAway).toHaveBeenCalled()

    handler.handle 'away', {}, "I'm", "busy"
    expect(onAway).toHaveBeenCalled()

  it "supports the op command", ->
    onOp = spyOn handler._handlers.op, 'run'
    handler.handle 'op', {}, 'othernick'
    expect(onOp).toHaveBeenCalled()

  it "only runs /join-server when online", ->
    onJoinServer = spyOn handler._handlers['join-server'], 'run'
    handler.handle 'join-server', {}
    expect(onJoinServer).toHaveBeenCalled()

    mocks.navigator.goOffline()
    handler._handlers['join-server'].run.reset()
    handler.handle 'join-server', {}
    expect(onJoinServer).not.toHaveBeenCalled()