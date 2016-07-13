exports.CircNode = function() {
  var Host = require('./host.js').Host;
  var IrcConnection = require('./irc-connection.js').IrcConnection;
  var CircState = require('../client/js/circ-state.js').CircState;

  function CircNode(server, name) {
    this.host = new Host(server, name);
    this.host.onconnection = this.onConnection_.bind(this);
    this.connections_ = {};
    this.clientId_ = 1;
    this.servers_ = {};
    this.state_ = {};
  }

  CircNode.prototype = {
    onConnection_: function(rtc, dataChannel) {
      var clientId = this.clientId_++;
      this.connections_[clientId] = {'rtc': rtc, 'dataChannel': dataChannel};
      rtc.oniceconnectionstatechange = this.onIceConnectionStateChange_.bind(this, clientId);
      dataChannel.addEventListener('message', this.onClientMessage_.bind(this, clientId));
      var stateJson = {};
      for (var serverId in this.state_) {
        stateJson[serverId] = this.state_[serverId].state;
      }
      dataChannel.send(JSON.stringify({'type': 'state', 'state': stateJson}));
    },
    onIceConnectionStateChange_: function(clientId) {
      var clientInfo = this.connections_[clientId];
      if (clientInfo.rtc.iceConnectionState == 'disconnected') {
        console.log('Client ' + clientId + ' disconnected');
        delete this.connections_[clientId];
      }
    },
    onClientMessage_: function(clientId, evt) {
      var message = JSON.parse(evt.data);
      if (message.type == 'connect') {
        // Add a name if missing.
        var name = message.name = message.name || message.address;
        if (this.servers_[name]) {
          this.connections_[clientId].dataChannel.send(JSON.stringify({'type': 'error', 'text': 'The specified server ' + name + ' already exists'}));
          return;
        }
        // TODO(flackr): Use a default nick if the options doesn't contain one.
        var server = this.servers_[name] = new IrcConnection(message.address, message.port, message.options.nick, message.options);
        server.onmessage = this.onServerMessage.bind(this, name);
        this.broadcast(message);
        server.onopen = function() {
          this.state_[name] = new CircState({});
          this.broadcast({'type': 'connected', 'server': name});
        }.bind(this);
        // TODO(flackr): Confirm when the server is actually connected.
      } else if (message.type == 'irc') {
        var server = this.servers_[message.server];
        if (!server) {
          this.connections_[clientId].dataChannel.send(JSON.stringify({'type': 'nack', 'reason': 'The specified server ' + message.server + ' does not exist'}));
          return;
        }
        this.connections_[clientId].dataChannel.send(JSON.stringify({'type': 'ack'}));
        server.send(message.command);
        this.broadcast(message);
      } else {
        console.error('Unrecognized message type ' + message.type);
      }
    },
    onServerMessage: function(serverId, data) {
      this.state_[serverId].process(data);
      this.broadcast({'type': 'server', 'server': serverId, 'data': data});
    },
    broadcast: function(data) {
      for (var clientId in this.connections_) {
        this.connections_[clientId].dataChannel.send(JSON.stringify(data));
      }
    },
  };

  return CircNode;
}()