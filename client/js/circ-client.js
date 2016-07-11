circ.CircClient = function() {
  
  function CircClient(server, name) {
    this.session = new circ.ClientSession(server, name);
    this.session.onconnection = this.onConnection_.bind(this);
    this.connections_ = {};
    this.hostId_ = 1;
    this.servers_ = {};
  }
  
  CircClient.prototype = {
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
        // TODO(flackr): Confirm when the server is actually connected.
      } else if (message.type == 'irc') {
        console.log('> ' + message.command);
      } else if (message.type == 'server') {
        console.log('< ' + message.data);
      } else {
        console.error('Unrecognized message type ' + message.type);
      }
    },
    send: function(hostId, data) {
      this.connections_[hostId].dataChannel.send(JSON.stringify(data));
    },
  };
  
  return CircClient;
}()