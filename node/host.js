/**
 * CIRC client makes the connection to the IRC server and shares it with
 * connected apps over WebRTC.
 */

var ws = require('ws');

console.log(ws);

exports.Host = function() {
  function Host(server, user) {
    this.socket = new WebSocket(server + '/' + user + '/host');
    this.socket.addEventListener('message', this.onServerMessage_.bind(this));
    this.connectingClients = {};
    this.clients = [];
    this.configuration = configuration || {
      iceServers: [
          {urls: "stun:stun.l.google.com:19302"},
      ],
    };
  }

  Host.prototype = {
    onServerMessage_: function(e) {
      var data = JSON.parse(e.data);
      if (data.type == "offer") {
        // TODO(flackr): Verify that there is no data here currently.
        var clientData = this.connectingClients[data.client] = {rtc: null, dataChannel: null};
        clientData.rtc = new RTCPeerConnection(this.configuration, null);
        clientData.rtc.ondatachannel = function(clientId, e) {
          clientData.dataChannel = e.channel;
          if (clientData.dataChannel.readyState == 'open')
            this.onClientConnected_(clientId);
          else
            this.dataChannel_.onopen = this.onClientConnected_.bind(this, clientId);
        }.bind(this, data.client);
        clientData.rtc.onicecandidate = function(event) {
          if (this.socket.readyState != 1 || !event.candidate)
            return;
            console.log('Send ice candidate');
          this.socket.send(JSON.stringify({'client': clientId, 'type':'candidate', 'data': event.candidate}));
        }.bind(this);
        clientData.rtc.oniceconnectionstatechange = this.onIceConnectionStateChange_.bind(this, clientData.rtc);
        clientData.rtc.setRemoteDescription(new RTCSessionDescription(data.data));
        clientData.rtc.createAnswer(function(desc) {
          if (this.socket.readyState != 1)
            return;
          clientData.rtc.setLocalDescription(desc);
          this.socket.send(JSON.stringify({'client': clientId, 'type': 'answer', 'data': desc}));
        }.bind(this), function(e) {
          console.log('Failed to create answer');
        });
      }
    },
    onClientConnected_: function(clientId) {
      var dataChannel = this.connectingClients[clientId].dataChannel;
      this.clients.push({
        'rtc': this.connectingClients[clientId].rtc,
        'dataChannel': dataChannel});
      // TODO(flackr): Maybe unbind the listeners?
      delete this.connectingClients[clientId];
      dataChannel.addEventListener('message', this.onClientMessage_.bind(this, dataChannel));
    },
    onIceConnectionStateChange_: function(rtc) {
      if (rtc.iceConnectionState != 'disconnected')
        return;
      // TODO(flackr): Maybe unbind listeners?
      // Check if it's a connecting client and remove connecting client data.
      for (var i in this.connectingClients) {
        if (this.connectingClients[i].rtc == rtc) {
          console.log('Connecting client ' + i + ' went away');
          delete this.connectingClients[i];
          return;
        }
      }
      // Otherwise, it should match an active connection.
      for (var i = 0; i < this.clients.length; i++) {
        if (this.clients[i].rtc == rtc) {
          console.log('Client disconnected');
          this.clients.splice(i, 1);
          return;
        }
      }
    },
    onClientMessage_: function(dataChannel, e) {
      console.log('Message received: ' + e.data);
    },
  };

  return Host;
}();