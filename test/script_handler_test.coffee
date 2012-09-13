describe 'A script handler', ->
  script = sh = emitter = onEmit = undefined

  sendMessage = (data) ->
    sh._handleMessage { source: script, data: data }

  beforeEach ->
    script = jasmine.createSpyObj 'script', ['postMessage']
    sh = new window.script.ScriptHandler()
    spyOn sh, 'emit'
    emitter = new EventEmitter
    sh.addScriptFrame(script)
    sh.intercept emitter

  afterEach ->
    sh.tearDown()

  it "intercepts events that have been hooked onto by a script", ->
    sendMessage { type: 'hook_command', 'say' }
    sendMessage { type: 'say', context: { server: '', channel: '' }, args: ['hi', 'there!'] }
    expect(sh.emit).not.toHaveBeenCalled()

  it "doesn't intercept events that have not been registered", ->
    sendMessage { type: 'say', context: { server: 'freenode', channel: '#sugarman' }, args: ['hi', 'there!'] }
    expect(sh.emit).toHaveBeenCalledWith('command', 'freenode', '#sugarman', 'say', 'hi', 'there')

  xit "sends 'command' when a registered command is entered", ->
    emitter.emit 'command', 'say', 'how is it going?'.split(' ')
#    expect(script.postMessage.calls.length).toEqual 1
#    data = script.postMessage.mostRecentCall.args[0].data
#    expect(data).toBe 'startup'

  xit "sends 'message' when a message is sent from a user", ->

  xit "sends 'message' when a message is sent from a server", ->

  xit "sends 'notification_clicked' when a notification is clicked", ->

  xit "sends 'scrolled_out_of_view' when a message scrolls out of view", ->
