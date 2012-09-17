describe 'A script handler', ->
  script1 = script2 = sh = emitter = onEmit = undefined

  sendMessage = (script, data) ->
    sh._handleMessage { source: script.frame, data }

  onCommand = jasmine.createSpy('onCommand')
  onUnknown = jasmine.createSpy('onUnknown')

  beforeEach ->
    mockFrame1 = { postMessage: -> }
    mockFrame2 = { postMessage: -> }
    script1 = new window.script.Script '1', mockFrame1
    script2 = new window.script.Script '2', mockFrame2
    spyOn script1, 'postMessage'
    spyOn script2, 'postMessage'
    sh = new window.script.ScriptHandler()
    spyOn(sh, 'emit').andCallThrough()
    emitter = new EventEmitter
    sh.addScript(script1)
    sh.addScript(script2)
    sh.intercept emitter
    onCommand.reset()
    onUnknown.reset()

  afterEach ->
    sh.tearDown()

  it "intercepts events that have been hooked", ->
    sendMessage script1, { type: 'hook_command', command: 'say' }
    emitter.emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    expect(sh.emit).not.toHaveBeenCalled()

  it "doesn't intercept events that haven't been hooked", ->
    sh.on 'command', onCommand
    sh.on 'unknown', onUnknown
    emitter.emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    emitter.emit 'unknown', 'blah'
    expect(onCommand).toHaveBeenCalledWith('freenode', '#bash', 'say', 'hey', 'there!')
    expect(onUnknown).toHaveBeenCalledWith('blah')

  it "sends an event when a hooked event is entered", ->
    sendMessage script1, { type: 'hook_command', command: 'say' }
    emitter.emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    data = script1.postMessage.mostRecentCall.args[0]

    expect(data.type).toBe 'command'
    expect(data.context.server).toBe 'freenode'
    expect(data.context.channel).toBe '#bash'
    expect(data.command).toBe 'say'
    expect(data.args).toEqual ['hey', 'there!']
    expect(data.id).toEqual(jasmine.any(Number))

  it "sends events only to the registered scripts", ->
    sendMessage script1, { type: 'hook_command', command: 'say' }
    emitter.emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'

    expect(script1.postMessage).toHaveBeenCalled()
    expect(script2.postMessage).not.toHaveBeenCalled()

  it "forwards events only after receiving 'prevent: none' from all scripts", ->
    sendMessage script1, { type: 'hook_command', command: 'say' }
    sendMessage script2, { type: 'hook_command', command: 'say' }
    emitter.emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    id1 = script1.postMessage.mostRecentCall.args[0].id
    id2 = script2.postMessage.mostRecentCall.args[0].id

    sendMessage script1, { type: 'propagation', prevent: 'none', id: id1 }
    expect(sh.emit).not.toHaveBeenCalled()
    sendMessage script2, { type: 'propagation', prevent: 'none', id: id2 }
    expect(sh.emit).toHaveBeenCalled()

  it "swallows events when received 'prevent: all' from at least one script", ->
    sendMessage script1, { type: 'hook_command', command: 'say' }
    sendMessage script2, { type: 'hook_command', command: 'say' }
    emitter.emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    id1 = script1.postMessage.mostRecentCall.args[0].id
    id2 = script2.postMessage.mostRecentCall.args[0].id

    sendMessage script1, { type: 'propagation', prevent: 'all', id: id1 }
    expect(sh.emit).not.toHaveBeenCalled()
    sendMessage script2, { type: 'propagation', prevent: 'none', id: id2 }
    expect(sh.emit).not.toHaveBeenCalled()

  it "sends 'command' when a registered command is entered", ->
    sendMessage script1, {
      type: 'command', context: { server: 'freenode', channel: '#bash' },
      command: 'say', args: ['hi', 'there!'] }
    expect(sh.emit).toHaveBeenCalledWith 'command', 'freenode', '#bash', 'say', 'hi', 'there!'

  xit "sends 'message' when a message is sent from a user", ->

  xit "sends 'message' when a message is sent from a server", ->

  xit "sends 'notification_clicked' when a notification is clicked", ->

  xit "sends 'scrolled_out_of_view' when a message scrolls out of view", ->

