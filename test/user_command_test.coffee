describe 'A user command', ->
  win = sayCommand = eatCommand = kickCommand = serverCommand = modeCommand = undefined
  onRun = jasmine.createSpy 'onRun'
  client = { determineWindow: -> win }

  eatCommandDescription =
    description: 'eats cake'
    params: ['numCakes']
    areValidArgs: ->
      @numCakes = parseInt @numCakes
    run: -> onRun @numCakes

  modeCommandDescription =
    description: 'sets the mode for a user (by default, yourself)'
    params: ['opt_nick', 'mode']
    requires: ['connection', 'channel', 'connected']
    areValidArgs: ->
      @nick ?= @conn.irc.nick
    run: -> onRun @nick, @mode

  sayCommandDescription =
    description: 'outputs text to the screen'
    params: ['text...']
    run: -> onRun @text

  kickCommandDescription =
    description: 'kicks a user from the current channel'
    params: ['nick', 'opt_reason...']
    run: -> onRun @nick, @reason

  serverCommandDescription =
    description: 'joins a server'
    params: ['opt_server', 'opt_port']
    run: -> onRun @server, @port

  getWindow = ->
    target: '#bash'
    conn:
      name: 'freenode.net'
      irc:
        state: 'connected'
        nick: 'ournick'
        channels: {}

  beforeEach ->
    mocks.navigator.useMock()
    onRun.reset()
    win = getWindow()
    eatCommand = new chat.UserCommand 'eat', eatCommandDescription
    sayCommand = new chat.UserCommand 'say', sayCommandDescription
    kickCommand = new chat.UserCommand 'kick', kickCommandDescription
    serverCommand = new chat.UserCommand 'server', serverCommandDescription
    modeCommand = new chat.UserCommand 'mode', modeCommandDescription
    modeCommand.setChat client
    modeCommand.setContext {}

  it 'parses arguments based on the params field', ->
    eatCommand.setArgs '8'
    eatCommand.run()
    expect(onRun).toHaveBeenCalledWith 8

  it 'can check if the given arguments are valid', ->
#    expect(eatCommand._hasValidArgs).toBe false
#
#    eatCommand.setArgs '4'
#    expect(eatCommand._hasValidArgs).toBe true
#
    eatCommand.setArgs 'donkey'
    expect(eatCommand._hasValidArgs).toBe false

#    eatCommand.setArgs('4', '5')
#    expect(eatCommand._hasValidArgs).toBe false
#
#    eatCommand.setArgs()
#    expect(eatCommand._hasValidArgs).toBe false

  it 'can require certain conditions to be met', ->
    win.conn.irc.state = 'disconnected'
    expect(modeCommand.canRun()).toBe false

    win.conn.irc.state = 'connected'
    expect(modeCommand.canRun()).toBe true

    win.target = undefined
    modeCommand.setChat client
    modeCommand.setContext {}
    expect(modeCommand.canRun()).toBe false

  it 'supports optional arguments', ->
    modeCommand.setArgs 'othernick', '+o'
    expect(modeCommand._hasValidArgs).toBe true

    modeCommand.setArgs '+o'
    expect(modeCommand._hasValidArgs).toBe true

    modeCommand.setArgs()
    expect(modeCommand._hasValidArgs).toBe false

    modeCommand.setArgs 'othernick', '+o', '#channel'
    expect(modeCommand._hasValidArgs).toBe false

  it 'supports variable number of arguments', ->
    expect(sayCommand.getHelp()).toBe 'SAY <text>, outputs text to the screen.'

    sayCommand.setArgs 'hi there'
    expect(sayCommand._hasValidArgs).toBe true

    sayCommand.run()
    expect(onRun).toHaveBeenCalledWith 'hi there'

    sayCommand.setArgs 'hey', 'guy'
    expect(sayCommand._hasValidArgs).toBe true
    sayCommand.run()
    expect(onRun).toHaveBeenCalledWith 'hey guy'

  it 'supports a mix of normal, optional and variable arguments', ->
    kickCommand.setArgs 'somenick'
    kickCommand.run()
    expect(onRun).toHaveBeenCalledWith 'somenick', undefined

    kickCommand.setArgs 'somenick', 'because', 'he', 'was', 'lame'
    kickCommand.run()
    expect(onRun).toHaveBeenCalledWith 'somenick', 'because he was lame'

    expect(kickCommand.getHelp()).toBe 'KICK <nick> [reason], kicks a user ' +
        'from the current channel.'

    kickCommand.setArgs()
    expect(kickCommand._hasValidArgs).toBe false

  it 'can have an optional arg before a normal arg', ->
    modeCommand = new chat.UserCommand 'mode', { params: ['opt_nick', 'mode'] }
    modeCommand.setArgs()
    expect(modeCommand._hasValidArgs).toBe false

  it 'provides a help message', ->
    expect(eatCommand.getHelp()).toBe 'EAT <numCakes>, eats cake.'

    expect(modeCommand.getHelp()).toBe 'MODE [nick] <mode>, ' +
        'sets the mode for a user (by default, yourself).'

  it "can't run of run isn't defined", ->
    danceDescription =
      description: "outputs dancing kirbys on the screen"
    danceCommand = new chat.UserCommand 'dance', danceDescription
    danceCommand.setChat client
    danceCommand.setContext {}
    expect(danceCommand.canRun()).toBe false

  it "can have no params", ->
    danceDescription =
      description: "outputs dancing kirbys on the screen"
      run: -> onRun('(>^.^)>')
    danceCommand = new chat.UserCommand 'dance', danceDescription

    expect(danceCommand.getHelp()).toBe "DANCE, outputs dancing kirbys on the screen."

    danceCommand.setArgs('hi')
    expect(danceCommand._hasValidArgs).toBe false

    danceCommand.setArgs()
    expect(danceCommand._hasValidArgs).toBe true

    danceCommand.run()
    expect(onRun).toHaveBeenCalledWith '(>^.^)>'

  it 'can have multiple optional params', ->
    serverCommand.setArgs()
    expect(serverCommand._hasValidArgs).toBe true

    serverCommand.setArgs('freenode')
    expect(serverCommand._hasValidArgs).toBe true

    serverCommand.run()
    expect(onRun).toHaveBeenCalledWith 'freenode', undefined

    serverCommand.setArgs('freenode', '6667')
    expect(serverCommand._hasValidArgs).toBe true

    serverCommand.run()
    expect(onRun).toHaveBeenCalledWith 'freenode', '6667'

    serverCommand.setArgs('freenode', '6667', 'extraparam')
    expect(serverCommand._hasValidArgs).toBe false

  it 'can extend other commands', ->
    yellDescription =
      description: 'outputs text to the screen in all caps'
      areValidArgs: ->
        @text = @text.toUpperCase()
    yellCommand = new chat.UserCommand 'yell', yellDescription
    yellCommand.describe sayCommandDescription

    expect(yellCommand.getHelp()).toBe 'YELL <text>, outputs text to the screen in all caps.'

    yellCommand.setArgs 'hi', 'bob'
    expect(yellCommand._hasValidArgs).toBe true

    yellCommand.run()
    expect(onRun).toHaveBeenCalledWith 'HI BOB'

  it 'can manually set usage message', ->
    command = new chat.UserCommand 'name', { usage: 'custom usage' }
    expect(command.getHelp()).toBe 'NAME custom usage.'

  it 'removes trailing white space', ->
    modeCommand.setArgs '+o', '', ''
    expect(modeCommand._hasValidArgs).toBe true