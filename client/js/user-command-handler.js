window.circ = window.circ || {};

circ.UserCommandHandler = function() {
  var commands = {
    'msg': {
      'args': ['channel', '...'],
      'helptext': 'foo',
      'run': function(handler, channel, message) {
        handler.client.send(handler.hostId_, handler.server_, 'PRIVMSG ' + channel + ' :' + message);
      }.bind()
    },
    'join': {
      'args': ['channel'],
      'helptext': 'foo',
      'run': function(handler, channel) {
        handler.client.join(handler.hostId_, handler.server_, channel);
      }.bind()
    },
  };

  function UserCommandHandler(client) {
    this.client = client;
  }

  UserCommandHandler.prototype = {
    setActiveChannel: function(hostId, server, channel) {
      this.hostId_ = hostId;
      this.server_ = server;
      this.channel_ = channel;
    },

    runCommand: function(input) {
      if (!input) return;
      if (input[0] != '/') {
        input = '/msg ' + this.channel_ + ' ' + input
      } else if (input == '/help') {
        // dump help.
        return;
      }
      var cmd = commands[input.split(' ', 1)[0].substring(1)];
      if (cmd) return cmd.run(this, ...this.getArgs(cmd, input));
      else throw new Error('invalid command');
    },

    getArgs: function(cmd, input) {
      var argList = cmd.args;
      if (argList[argList.length - 1] != '...') {
        var inputArgs = input.split(' ', argList.length + 2);
        if (inputArgs.length > argList.length + 1 || inputArgs.length <= argList.length)
          throw new Error('invalid command');
        return inputArgs.slice(1);
      } else {
        var inputArgs = input.split(' ', argList.length);
        if (inputArgs.length < argList.length)
          throw new Error('invalid command');
        inputArgs.push(input.substring(inputArgs.reduce(function(a, b) { return a + b.length + 1; }, 0)));
        return inputArgs.slice(1);
      }
    },

    // Override these functions to be notified about various events.
    onjoin: function(channel) {},

    process: function(message, timestamp) {
    }
  }

  return UserCommandHandler;
}();