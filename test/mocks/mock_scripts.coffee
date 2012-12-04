exports = window.mocks ?= {}

class Scripts

  useMock: ->
    window.script.Script.scriptCount = 0

  simpleSourceCode: """
    var data = { msg: 'hi!', script: window.script };
    parent.window.postMessage(data, '*');
    addEventListener('message', function(e) {
      e.source.postMessage(e.data, '*');
    });
  """

  maliciousSourceCode: """
    chromeAPI = 'none';
    try {
      chromeAPI = window.parent.chrome;
    } catch (ex) { }
    parent.window.postMessage({chromeAPI: chromeAPI}, '*');
  """

  hiSourceCode: """
    setName('/hi');
    send('hook_command', 'hi');
    onMessage = function(e) {
      send(e.context, 'command', 'say', 'hello world');
      propagate(e, 'none');
    };
  """

exports.scripts = new Scripts