var Socket = require('net').Socket;

exports.IrcConnection = function() {
  
  var EOL = '\r\n';

  function IrcConnection(address, port, nick, options) {
    // TODO(flackr): Support SSL connections
    this.nick = nick;
    this.options = options;
    // Use the nickname as the user if not specified.
    this.user = this.options.user || this.nick;
    this.realName = this.options.realName || 'A CIRC user'; 
    this.socket = new Socket();
    this.socket.connect(port, address, this.onConnected_.bind(this));
    this.socket.on('data', this.onData_.bind(this));
    this.socket.on('close', this.onClose_.bind(this));
    // TODO(flackr): It's probably not efficient to do string concatenation
    // and splitting to accumulate the messages - we should do something better.
    this.receiveBuffer_ = '';
  }
  
  IrcConnection.prototype = {
    onopen: function() {},
    onmessage: function(message) {},
    
    send: function(message) {
      this.socket.write(message + EOL);
    },
    onConnected_: function() {
      this.socket.write('NICK ' + this.nick + EOL);
      this.socket.write('USER ' + this.user + ' 0 * :' + this.realName + EOL);
      this.onopen();
    },
    onData_: function(data) {
      this.receiveBuffer_ += data;
      var messages = this.receiveBuffer_.split(EOL);
      for (var i = 0; i < messages.length - 1; i++) {
        this.onMessage_(messages[i]);
      }
      // Whatever is past the last EOL is not complete.
      this.receiveBuffer_ = messages[messages.length - 1];
    },
    onMessage_: function(message) {
      var cmd = message.split(' ', 2)[0];
      if (cmd == 'PING') {
        this.send('PONG ' + cmd[1]);
        console.log('Responding to server ping');
        return;
      }
      this.onmessage(message);
    },
    onClose_: function() {
      // TODO(flackr): Something meaningful!
    },
  };

  return IrcConnection;
}();