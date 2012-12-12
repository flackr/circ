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

  storageSourceCode: """
    var sum = 0;
    setName('sum');
    loadFromStorage();

    var addToSum = function(amount) {
      amount = parseInt(amount);
      if (!isNaN(amount)) {
        sum += amount;
        saveToStorage(sum);
        return true;
      }
      return false;
    };

    onMessage = function(e) {
      propagate(e, 'none');

      if (e.type == 'system' && e.name == 'loaded') {
        addToSum(e.args[0]);

      } else if (e.type == 'command' && e.name == 'add') {
        success = addToSum(e.args[0]);
        if (success) {
          send(e.context, 'message', 'notice', 'Sum so far: ' + sum);
        }
      }
    };

    send('hook_command', 'add');
  """

exports.scripts = new Scripts
