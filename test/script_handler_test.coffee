describe 'A script handler', ->
  script1 = script2 = handler = emitter = onEmit = undefined

  sendMessage = (script, event) ->
    handler._handleMessage { source: script.frame, data: event }

  emit = (type, server, channel, name, args...) ->
    event = new Event(type, name, args...)
    event.setContext server, channel
    emitter.emit type, event

  onCommand = jasmine.createSpy('onCommand')
  onUnknown = jasmine.createSpy('onUnknown')

  beforeEach ->
    mockFrame1 = { postMessage: -> }
    mockFrame2 = { postMessage: -> }
    script1 = new window.script.Script '1', mockFrame1
    script2 = new window.script.Script '2', mockFrame2
    spyOn script1, 'postMessage'
    spyOn script2, 'postMessage'
    handler = new window.script.ScriptHandler()
    spyOn(handler, 'emit').andCallThrough()
    emitter = new EventEmitter
    handler.addScript(script1)
    handler.addScript(script2)
    handler.addEventsFrom emitter
    onCommand.reset()
    onUnknown.reset()

  afterEach ->
    handler.tearDown()

  it "intercepts user commands that have been hooked", ->
    sendMessage script1, { type: 'hook_command', name: 'say' }
    emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    expect(handler.emit).not.toHaveBeenCalled()

  it "doesn't intercepts user commands that cannot be intercepted", ->
    sendMessage script1, { type: 'hook_command', name: 'help' }
    emit 'command', 'freenode', '#bash', 'help'
    expect(handler.emit).toHaveBeenCalled()

  it "intercepts server messages that have been hooked", ->
    sendMessage script1, { type: 'hook_server', name: 'joined' }
    emit 'server', 'freenode', '', 'joined', '#bash'
    expect(handler.emit).not.toHaveBeenCalled()

  it "doesn't intercept events that haven't been hooked", ->
    handler.on 'command', onCommand
    handler.on 'unknown', onUnknown
    emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    emit 'unknown'
    expect(onCommand).toHaveBeenCalled()
    expect(onUnknown).toHaveBeenCalled()

  it "sends an event when a hooked event is entered", ->
    sendMessage script1, { type: 'hook_command', name: 'say' }
    emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    event = script1.postMessage.mostRecentCall.args[0]

    expect(event.type).toBe 'command'
    expect(event.context.server).toBe 'freenode'
    expect(event.context.channel).toBe '#bash'
    expect(event.name).toBe 'say'
    expect(event.args).toEqual ['hey', 'there!']
    expect(event.id).toEqual(jasmine.any(Number))

  it "sends events only to the scripts that have hooked them", ->
    sendMessage script1, { type: 'hook_command', name: 'say' }
    emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'

    expect(script1.postMessage).toHaveBeenCalled()
    expect(script2.postMessage).not.toHaveBeenCalled()

  it "forwards events only after receiving 'propagate: all' from all scripts", ->
    sendMessage script1, { type: 'hook_command', name: 'say' }
    sendMessage script2, { type: 'hook_command', name: 'say' }
    emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    id1 = script1.postMessage.mostRecentCall.args[0].id
    id2 = script2.postMessage.mostRecentCall.args[0].id

    sendMessage script1, { type: 'propagate', name: 'all', args: [id1] }
    expect(handler.emit).not.toHaveBeenCalled()
    sendMessage script2, { type: 'propagate', name: 'all', args: [id2] }
    expect(handler.emit).toHaveBeenCalled()

  it "swallows events when received 'propagate: none' from at least one script", ->
    sendMessage script1, { type: 'hook_command', name: 'say' }
    sendMessage script2, { type: 'hook_command', name: 'say' }
    emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    id1 = script1.postMessage.mostRecentCall.args[0].id
    id2 = script2.postMessage.mostRecentCall.args[0].id

    sendMessage script1, { type: 'propagate', name: 'all', args: [id1] }
    expect(handler.emit).not.toHaveBeenCalled()
    sendMessage script2, { type: 'propagate', name: 'none', args: [id2] }
    expect(handler.emit).not.toHaveBeenCalled()

  it "sends 'command' when a registered command is entered", ->
    sendMessage script1, {
      type: 'command', context: { server: 'freenode', channel: '#bash' },
      name: 'say', args: ['hi', 'there!'] }
    expect(handler.emit).toHaveBeenCalled()
