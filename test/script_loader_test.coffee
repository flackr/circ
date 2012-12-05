describe 'A script loader', ->
  sl = frame = undefined
  numFrames = undefined

  onMessage = jasmine.createSpy 'onMessage'
  addEventListener 'message', onMessage

  waitsForScriptToLoad = ->
    waitsFor (-> onMessage.calls.length > 1),
      'onMessage should have been called', 500

  waitsForCommandToBeHooked = ->
    waitsFor ->
      return false if onMessage.calls.length is 0
      return onMessage.mostRecentCall.args[0].data.type is 'hook_command'
    , 'a command should have been hooked', 500

  beforeEach ->
    onMessage.reset()
    numFrames = $('iframe').length
    sl = window.script.loader

  afterEach ->
    $('iframe').remove()

  it 'creates an invisible iframe on createScript()', ->
    script = sl._createScript mocks.scripts.simpleSourceCode
    expect($('iframe').length).toEqual numFrames + 1
    expect($('iframe')[0].style.display).toBe 'none'

  it 'calls eval() on the script source code', ->
    script = sl._createScript mocks.scripts.simpleSourceCode
    waitsForScriptToLoad()
    runs ->
      data = onMessage.mostRecentCall.args[0].data
      expect(data.msg).toEqual 'hi!'
      expect(data.script).toBeUndefined()

  it 'provides convenience functions for scripts', ->
    script = sl._createScript mocks.scripts.hiSourceCode
    waitsForCommandToBeHooked()
    runs ->
      hookCommandEvent = onMessage.mostRecentCall.args[0].data
      expect(hookCommandEvent.name).toBe 'hi'

      nameEvent = onMessage.calls[1].args[0].data
      expect(nameEvent.type).toBe 'meta'
      expect(nameEvent.name).toBe 'name'
      expect(nameEvent.args[0]).toBe '/hi'

  it 'has the script run in a sandbox', ->
    script = sl._createScript mocks.scripts.maliciousSourceCode
    waitsForScriptToLoad()
    runs ->
      data = onMessage.mostRecentCall.args[0].data
      expect(data.chromeAPI).toBeUndefined()

  it 'can auto-load prepackaged scripts', ->
    calls = 0
    sl.loadPrepackagedScripts -> calls++
    expect($('iframe').length).toEqual numFrames + calls