var EOL = '\r\n';

function IRCServer(address, port) {
  this.server = new MockSocketServer(port, address);
  this.server.on('connection', this.onConnection.bind(this));
  this.connections = {};
  this.clientId = 1;
}

IRCServer.prototype = {
  onConnection: function(connection) {
    var id = this.clientId++;
    // TODO(flackr): State enum?
    this.connections[id] = {'socket': connection, state: 0};
    connection.on('data', this.onData.bind(this, id));
  },
  
  onData: function(id, data) {
    var cmds = data.split('\r\n');
    for (var i = 0; i < cmds.length; i++) {
      var cmd = cmds[i].split(' ');
      if (cmd == 'NICK') {
        this.connections[id].nick = cmd[1];
      } else if (cmd == 'USER') {
        // Send preamble.
      }
    }
  },
};