describe 'A script command handler', ->
  sc = onCommand = undefined

  handle = (argObj) ->
    sc.handle argObj.type, argObj

  beforeEach ->
    onCommand = jasmine.createSpy 'onCommand'
    sc = new window.script.ScriptCommandHandler()
    sc.setCallback onCommand

  it "handles the 'register_command' command", ->
    expect(sc.canHandle('register_command')).toBe true
    handle { type: 'register_command', command: 'kick' }
    expect(onCommand).toHaveBeenCalledWith 'register_command', 'kick'

  it "handles the 'input' command", ->
    expect(sc.canHandle('input')).toBe true
    handle { type: 'input', channel: '#bash', server: 'freenode.net', input: '/join #bash2' }
    expect(onCommand).toHaveBeenCalledWith 'input', '#bash', 'freenode.net', '/join #bash2'

  it "handles the 'notify' command", ->
    expect(sc.canHandle('notify')).toBe true
    handle { type: 'notify', title: 'hi!', body: 'body text', id: 1234, timeout: 500 }
    expect(onCommand).toHaveBeenCalledWith 'notify', 'hi!', 'body text', 1234, 500