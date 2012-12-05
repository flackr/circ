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

  invalidNameSourceCode: """
    setName('invalid name');
    send('hook_command', 'hi');
  """

  longNameSourceCode: """
    setName('123456789012345678901234567890');
    send('hook_command', 'hi');
  """

  noNameSourceCode: """
    send('hook_command', 'hi');
  """

exports.scripts = new Scripts