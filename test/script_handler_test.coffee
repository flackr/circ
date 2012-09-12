describe 'A script handler', ->
  sh = undefined
  script = jasmine.createSpyObj 'script', ['postMessage']

  beforeEach ->
    sh = new window.script.ScriptHandler()
    sh.addScriptFrame(script)

  afterEach ->
    sh.tearDown()

  it "sends 'startup' on startup", ->
    expect(script.postMessage.calls.length).toEqual 1
    msg = script.postMessage.mostRecentCall.args[0]
    expect(msg.type).toBe 'startup'

  xit "sends 'command' when a registered command is entered", ->

  xit "does not send 'command' when a non-registered command is entered", ->

  xit "sends 'message' when a message is sent from a user", ->

  xit "sends 'message' when a message is sent from a server", ->

  xit "sends 'notification_clicked' when a notification is clicked", ->

  xit "sends 'scrolled_out_of_view' when a message scrolls out of view", ->
