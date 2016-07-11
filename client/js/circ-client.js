circ.CircClient = function() {
  
  function CircClient(server, name) {
    this.addEventTypes(['connection', 'message', 'server']);
    this.session = new circ.ClientSession(server, name);
    this.session.onconnection = this.onConnection_.bind(this);
    this.connections_ = {};
    this.hostId_ = 1;
    this.servers_ = {};
  }
  
  CircClient.prototype = circ.util.extend(circ.util.EventSource.prototype, {
    onConnection_: function(rtc, dataChannel) {
      var hostId = this.hostId_++;
      this.connections_[hostId] = {'rtc': rtc, 'dataChannel': dataChannel};
      rtc.oniceconnectionstatechange = this.onIceConnectionStateChange_.bind(this, hostId);
      dataChannel.addEventListener('message', this.onHostMessage_.bind(this, hostId));
      this.dispatchEvent('connection', hostId);
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
      if (message.type == 'connect') {
        // Ignored for now - the server isn't actually connected yet. We'll add
        // it to the list when we confirm it's connected.
        console.log('connect ' + message.data)
      } else if (message.type == 'connected') {
        var server = message.server;
        this.servers_[server] = hostId;
        this.dispatchEvent('server', hostId, message.server);
        // TODO(flackr): Confirm when the server is actually connected.
      } else if (message.type == 'irc') {
        console.log('> ' + message.command);
      } else if (message.type == 'server') {
        this.dispatchEvent('message', hostId, message.server, message.data);
        console.log('< ' + message.data);
      } else {
        console.error('Unrecognized message type ' + message.type);
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
      // TODO(flackr): Name should no longer be part of options as it's always
      // generated on the client and passed across the data channel.
      options.name = options.name || address;
      return new Promise(function(resolve, reject) {
        // TODO(flackr): Listen for failures like host disconnecting or server
        // not reachable and call reject.
        var listener = function(host, serverName) {
          if (host != hostId || serverName != options.name)
            return;
          this.removeEventListener('server', listener);
          resolve();
        }.bind(this);
        this.addEventListener('server', listener);
        this.send(hostId, {'type': 'connect', 'address': address, 'port': port, 'options': options});
      }.bind(this));
    },
    send: function(hostId, data) {
      this.connections_[hostId].dataChannel.send(JSON.stringify(data));
    },
  });
  
  return CircClient;
}()