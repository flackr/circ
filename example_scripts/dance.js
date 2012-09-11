validOrigin = 'www.some-valid-origin.com';

function init() {
  addEventListener('message', function(e) {
    if (e.origin != validOrigin) {
      return;
    }

    if (e.data.type == 'startup') {
      registerDanceCommand(e);
    }

    if (e.data.type == 'command') {
      doDance(e);
    }
  });
}

function registerDanceCommand(e) {
  cmd = {
    type: 'register_command',
    command: 'dance'
  };
  e.source.postMessage(cmd, '*');
};

function doDance(e) {
  cmd = {
    type: 'input',
    channel: e.data.channel,
    server: e.data.server,
    input: "(>'-')> <('-'<) ^(' - ')^ <('-'<) (>'-')>"
  };
  e.source.postMessage(cmd, '*');
};

init();