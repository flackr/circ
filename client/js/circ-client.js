circ.CircClient = function() {
  
  function CircClient(server, name) {
    this.addEventTypes(['connection', 'message', 'server']);
    this.session = new circ.ClientSession(server, name);
    this.session.onconnection = this.onConnection_.bind(this);
    this.state = {};
    this.connections_ = {};
    this.hostId_ = 1;
    this.pendingMessages_ = [];
  }
  
  CircClient.prototype = circ.util.extend(circ.util.EventSource.prototype, {
    onConnection_: function(rtc, dataChannel) {
      var hostId = this.hostId_++;
      this.connections_[hostId] = {'rtc': rtc, 'dataChannel': dataChannel};
      rtc.oniceconnectionstatechange = this.onIceConnectionStateChange_.bind(this, hostId);
      dataChannel.addEventListener('message', this.onHostMessage_.bind(this, hostId));
    },
    onIceConnectionStateChange_: function(hostId) {
      // TODO(flackr): When a host goes away, we lose our connection to every
      // irc server connected to through that host - we should track this and
      // update the UI accordingly.
      var hostInfo = this.connections_[hostId];
      if (hostInfo.rtc.iceConnectionState == 'disconnected') {
        console.log('Host ' + hostId + ' disconnected');
        hostInfo.rtc.oniceconnectionstatechange = null;
        delete this.connections_[hostId];
      }
    },
    onHostMessage_: function(hostId, evt) {
      var message = JSON.parse(evt.data);
      if (message.type == 'state') {
        this.state[hostId] = message.state;
        this.dispatchEvent('connection', hostId);
      } else if (message.type == 'connect') {
        // Ignored for now - the server isn't actually connected yet. We'll add
        // it to the list when we confirm it's connected.
        console.log('connect ' + message.data)
      } else if (message.type == 'connected') {
        var server = message.server;
        this.state[hostId][server] = {};
        this.dispatchEvent('server', hostId, server);
        // TODO(flackr): Confirm when the server is actually connected.
      } else if (message.type == 'irc') {
        console.log('> ' + message.command);
      } else if (message.type == 'server') {
        var cmd = message.data.split(' ', 3);
        if (cmd[1] == 'JOIN') {
          // TODO: Add the user specified to the user list if this is an already
          // connected channel.
          this.state[hostId][message.server][cmd[2].substring(1)] = {};
        }
        this.dispatchEvent('message', hostId, message.server, message.data);
        console.log('< ' + message.data);
      } else if (message.type == 'ack') {
        this.pendingMessages_.shift().resolve();
      } else if (message.type == 'nack') {
        this.pendingMessages_.shift().reject();
      } else {
        console.warn('Unrecognized message type', message);
      }
    },

    /**
     * Connect to a new IRC server.
     * 
     * @param {number} hostId The host to connect to the IRC server on.
     * @param {string} address The address for the IRC server (e.g. chat.freenode.net)
     * @param {number} port The port number to connect (e.g. 6667).
     * @param {{name: ?string,
     *          nick: ?string,
     *          ssl: ?boolean,
     *          user: ?string,
     *          password: ?string}} options
     *     Additional connection parameters.
     */
    connect: function(hostId, address, port, options) {
      options = options || {};
      var name = options.name || address;
      return new Promise(function(resolve, reject) {
        // TODO(flackr): Listen for failures like host disconnecting or server
        // not reachable and call reject.
        var listener = function(host, serverName) {
          if (host != hostId || serverName != name)
            return;
          this.removeEventListener('server', listener);
          resolve();
        }.bind(this);
        this.addEventListener('server', listener);
        this.send_(hostId, {'type': 'connect', 'address': address, 'port': port, 'name': name, 'options': options});
      }.bind(this));
    },
    join: function(hostId, server, channel) {
      return new Promise(function(resolve, reject) {
        this.pendingMessages_.push({'resolve': function() {
          var listener = function(hostId, serverName, message) {
            var words = message.split(' ', 3);
            if (words[1] != "JOIN" || words[2] != ":" + channel)
              return;
            this.removeEventListener('message', listener);
            resolve();
          }.bind(this);
          this.addEventListener('message', listener);
        }.bind(this), 'reject': reject});
        this.send_(hostId, {'type': 'irc', 'server': server, 'command': 'JOIN ' + channel});
      }.bind(this));
    },
    send: function(hostId, server, message) {
      return new Promise(function(resolve, reject) {
        this.pendingMessages_.push({'resolve': resolve, 'reject': reject});
        this.send_(hostId, {'type': 'irc', 'server': server, 'command': message});
      }.bind(this));
    },
    send_: function(hostId, data) {
      this.connections_[hostId].dataChannel.send(JSON.stringify(data));
    },
  });
  
  return CircClient;
}()