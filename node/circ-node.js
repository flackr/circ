exports.CircNode = function() {
  var Host = require('./host.js').Host;
  var IrcConnection = require('./irc-connection.js').IrcConnection;
  var CircState = require('../client/js/circ-state.js').CircState;
  var webPush;
  if (process.env.GCM_API_KEY) {
    webPush = require('web-push');
    webPush.setGCMAPIKey(process.env.GCM_API_KEY);
  } else {
    console.warn('Push notifications require the environment variable GCM_API_KEY');
  }
  var XMLHttpRequest = require('xmlhttprequest');

  function CircNode(server, name) {
    this.host = new Host(server, name);
    this.host.onconnection = this.onConnection_.bind(this);
    this.pushEndpoints = {};
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
        clientInfo.rtc.oniceconnectionstatechange = null;
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
          this.state_[name] = new CircState({'nick': message.options.nick});
          this.state_[name].onevent = this.onIrcEvent.bind(this, name);
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
        message.time = Date.now();
        server.send(message.command);
        this.broadcast(message);
        this.state_[message.server].processOutbound(message.command, message.time);
      } else if (message.type == 'subscribe') {
        this.pushEndpoints[message.endpoint] = true;
        // TODO(flackr): Add a way to unsubscribe.
      } else {
        console.error('Unrecognized message type ' + message.type);
      }
    },
    onServerMessage: function(serverId, data) {
      var timestamp = Date.now();
      this.state_[serverId].process(data, timestamp);
      this.broadcast({'type': 'server', 'server': serverId, 'data': data, 'time': timestamp});
    },
    onIrcEvent: function(server, channel, event) {
      if (event.type != 'PRIVMSG')
        return;
      // We're only looking for events from other people with your nickname in them.
      var nick = this.state_[server].state.nick;
      if (event.from == nick || event.data.indexOf(nick) == -1)
        return;
      this.sendPush(server, channel, event);
    },
    sendPush: function(server, channel, event) {
      if (!webPush)
        return;
      // TODO(flackr): Add tests for push notifications.
      for (var endpoint in this.pushEndpoints) {
        webPush.sendNotification(endpoint);
      }
    },
    broadcast: function(data) {
      for (var clientId in this.connections_) {
        this.connections_[clientId].dataChannel.send(JSON.stringify(data));
      }
    },
  };

  return CircNode;
}()