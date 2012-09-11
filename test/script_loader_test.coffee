describe 'A script loader', ->
  sl = frame = onMessage = undefined
  numFrames = undefined

  script = """
    addEventListener('message', function(e) {
      var response = {
        received: e.data,
        script: window.script
      }
      e.source.postMessage(response, '*');
    });
  """

  waitsForScriptToRespond = ->
    waitsFor (-> onMessage.calls.length > 0),
      'onMessage should have been called', 500

  beforeEach ->
    onMessage = jasmine.createSpy 'onMessage'
    addEventListener 'message', onMessage
    numFrames = $('iframe').length

    sl = new window.script.ScriptLoader()
    frame = sl.loadIntoFrame script
    frame.postMessage 'hi!', '*'

  it 'creates an invisible iframe on loadIntoFrame()', ->
    expect($('iframe').length).toEqual numFrames + 1
    expect($('iframe')[0].style.display).toBe 'none'

  it 'calls eval() on the script source code', ->
    waitsForScriptToRespond()
    runs ->
      data = onMessage.mostRecentCall.args[0].data
      expect(data.received).toEqual 'hi!'

  it 'has the script run in a sandbox', ->
    waitsForScriptToRespond()
    runs ->
      data = onMessage.mostRecentCall.args[0].data
      expect(data.script).toBeUndefined()
