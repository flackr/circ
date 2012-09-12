describe 'A script loader', ->
  sl = frame = undefined
  numFrames = undefined

  onMessage = jasmine.createSpy 'onMessage'
  addEventListener 'message', onMessage

  script = """
    var data = { msg: 'hi!', script: window.script };
    parent.window.postMessage(data, '*');
    addEventListener('message', function(e) {
      e.source.postMessage(e.data, '*');
    });
  """

  maliciousScript = """
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

  it 'creates an invisible iframe on loadIntoFrame()', ->
    frame = sl.loadIntoFrame script
    expect($('iframe').length).toEqual numFrames + 1
    expect($('iframe')[0].style.display).toBe 'none'

  it 'calls eval() on the script source code', ->
    frame = sl.loadIntoFrame script
    waitsForScriptToLoad()
    runs ->
      data = onMessage.mostRecentCall.args[0].data
      expect(data.msg).toEqual 'hi!'
      expect(data.script).toBeUndefined()

  it 'has the script run in a sandbox', ->
    frame = sl.loadIntoFrame maliciousScript
    waitsForScriptToLoad()
    runs ->
      data = onMessage.mostRecentCall.args[0].data
      expect(data.chromeAPI).toBeUndefined()
