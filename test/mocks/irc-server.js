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
    this.connections[id] = {'socket': connection, state: 'connecting'};
    connection.on('data', this.onData.bind(this, id));
  },
  
  onData: function(id, data) {
    var cmds = data.split('\r\n');
    for (var i = 0; i < cmds.length; i++) {
      var cmd = cmds[i].split(' ');
      if (cmd[0] == 'NICK') {
        var oldNick = this.connections[id].nick;
        this.connections[id].nick = cmd[1];
        if (this.connections[id].state == 'connected') {
          this.connections[id].socket.write(':' + oldNick + '! NICK :' + cmd[1] + EOL);
        }
      } else if (cmd[0] == 'USER') {
        // Send preamble.
        this.connections[id].state = 'connected';
      } else if (cmd[0] == 'JOIN') {
        this.connections[id].socket.write(':' + this.connections[id].nick + '! JOIN :' + cmd[1] + EOL);
      }
    }
  },
};