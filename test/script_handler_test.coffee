describe 'A script handler', ->
  script1 = script2 = sh = emitter = onEmit = undefined

  sendMessage = (script, event) ->
    sh._handleMessage { source: script.frame, data: event }

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
    sh = new window.script.ScriptHandler()
    spyOn(sh, 'emit').andCallThrough()
    emitter = new EventEmitter
    sh.addScript(script1)
    sh.addScript(script2)
    sh.addEventsFrom emitter
    onCommand.reset()
    onUnknown.reset()

  afterEach ->
    sh.tearDown()

  it "intercepts user commands that have been hooked", ->
    sendMessage script1, { type: 'hook_command', name: 'say' }
    emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    expect(sh.emit).not.toHaveBeenCalled()

  it "intercepts server messages that have been hooked", ->
    sendMessage script1, { type: 'hook_server', name: 'joined' }
    emit 'server', 'freenode', '', 'joined', '#bash'
    expect(sh.emit).not.toHaveBeenCalled()

  it "doesn't intercept events that haven't been hooked", ->
    sh.on 'command', onCommand
    sh.on 'unknown', onUnknown
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
    expect(sh.emit).not.toHaveBeenCalled()
    sendMessage script2, { type: 'propagate', name: 'all', args: [id2] }
    expect(sh.emit).toHaveBeenCalled()

  it "swallows events when received 'propagate: none' from at least one script", ->
    sendMessage script1, { type: 'hook_command', name: 'say' }
    sendMessage script2, { type: 'hook_command', name: 'say' }
    emit 'command', 'freenode', '#bash', 'say', 'hey', 'there!'
    id1 = script1.postMessage.mostRecentCall.args[0].id
    id2 = script2.postMessage.mostRecentCall.args[0].id

    sendMessage script1, { type: 'propagate', name: 'all', args: [id1] }
    expect(sh.emit).not.toHaveBeenCalled()
    sendMessage script2, { type: 'propagate', name: 'none', args: [id2] }
    expect(sh.emit).not.toHaveBeenCalled()

  it "sends 'command' when a registered command is entered", ->
    sendMessage script1, {
      type: 'command', context: { server: 'freenode', channel: '#bash' },
      name: 'say', args: ['hi', 'there!'] }
    expect(sh.emit).toHaveBeenCalled()

  xit "sends 'message' when a message is sent from a user", ->

  xit "sends 'message' when a message is sent from a server", ->

  xit "sends 'notification_clicked' when a notification is clicked", ->

  xit "sends 'scrolled_out_of_view' when a message scrolls out of view", ->

