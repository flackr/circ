describe 'A script loader', ->
  sl = frame = undefined
  numFrames = undefined

  onMessage = jasmine.createSpy 'onMessage'
  addEventListener 'message', onMessage

  sourceCode = """
    var data = { msg: 'hi!', script: window.script };
    parent.window.postMessage(data, '*');
    addEventListener('message', function(e) {
      e.source.postMessage(e.data, '*');
    });
  """

  maliciousSourceCode = """
    chromeAPI = 'none';
    try {
      chromeAPI = window.parent.chrome;
    } catch (ex) { }
    parent.window.postMessage({chromeAPI: chromeAPI}, '*');
  """

  waitsForScriptToLoad = ->
    waitsFor (-> onMessage.calls.length > 1),
      'onMessage should have been called', 500

  beforeEach ->
    onMessage.reset()
    numFrames = $('iframe').length
    sl = window.script.loader

  afterEach ->
    $('iframe').remove()

  it 'creates an invisible iframe on createScript()', ->
    script = sl._createScript sourceCode
    expect($('iframe').length).toEqual numFrames + 1
    expect($('iframe')[0].style.display).toBe 'none'

  it 'calls eval() on the script source code', ->
    script = sl._createScript sourceCode
    waitsForScriptToLoad()
    runs ->
      data = onMessage.mostRecentCall.args[0].data
      expect(data.msg).toEqual 'hi!'
      expect(data.script).toBeUndefined()

  it 'has the script run in a sandbox', ->
    script = sl._createScript maliciousSourceCode
    waitsForScriptToLoad()
    runs ->
      data = onMessage.mostRecentCall.args[0].data
      expect(data.chromeAPI).toBeUndefined()

  it 'can auto-load prepackaged scripts', ->
    calls = 0
    sl.loadPrepackagedScripts -> calls++
    expect($('iframe').length).toEqual numFrames + calls
