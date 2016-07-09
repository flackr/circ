/**
 * CIRC client makes the connection to the IRC server and shares it with
 * connected apps over WebRTC.
 */

var ws = require('ws');

console.log(ws);

exports.Host = function() {
  function Host(server, user) {
    this.socket = new WebSocket(server + '/' + user + '/host');
    this.socket.addEventListener('open', this.onServerConnected_.bind(this));
    this.socket.addEventListener('message', this.onServerMessage_.bind(this));
    this.connectingClientCount = 0;
    this.connectingClients = {};
    this.clients = [];
    this.configuration = {
      iceServers: [
          {urls: "stun:stun.l.google.com:19302"},
      ],
    };
  }

  Host.prototype = {
    onopen: function() {},
    onconnection: function(rtc, dataChannel) {},
    onconnecting: function(clientCount) {},
    
    onServerConnected_: function(e) {
      this.onopen();
    },
    onServerMessage_: function(e) {
      var data = JSON.parse(e.data);
      if (data.type == "offer") {
        this.connectingClientCount++;
        this.onconnecting(this.connectingClientCount);
        // TODO(flackr): Verify that there is no data here currently.
        var clientData = this.connectingClients[data.client] = {rtc: null, dataChannel: null};
        clientData.rtc = new RTCPeerConnection(this.configuration, null);
        clientData.rtc.ondatachannel = function(clientId, e) {
          clientData.dataChannel = e.channel;
          if (clientData.dataChannel.readyState == 'open')
            this.onClientConnected_(clientId);
          else
            clientData.dataChannel.onopen = this.onClientConnected_.bind(this, clientId);
        }.bind(this, data.client);
        clientData.rtc.onicecandidate = function(clientId, event) {
          if (this.socket.readyState != 1 || !event.candidate)
            return;
            console.log('Send ice candidate');
          this.socket.send(JSON.stringify({'client': clientId, 'type':'candidate', 'data': event.candidate}));
        }.bind(this, data.client);
        clientData.rtc.oniceconnectionstatechange = this.onIceConnectionStateChange_.bind(this, clientData.rtc);
        clientData.rtc.setRemoteDescription(new RTCSessionDescription(data.data));
        clientData.rtc.createAnswer(function(clientId, desc) {
          if (this.socket.readyState != 1)
            return;
          clientData.rtc.setLocalDescription(desc);
          this.socket.send(JSON.stringify({'client': clientId, 'type': 'answer', 'data': desc}));
        }.bind(this, data.client), function(e) {
          console.log('Failed to create answer');
        });
      } else if (data.type == 'candidate' && this.connectingClients[data.client].rtc.signalingState != 'closed') {
        this.connectingClients[data.client].rtc.addIceCandidate(new RTCIceCandidate(data.data));
      } else if (data.type == 'close') {
        this.connectingClientCount--;
        this.onconnecting(this.connectingClientCount);
      } else {
        console.error('Unhandled message type ' + data.type);
      }
    },
    onClientConnected_: function(clientId) {
      var clientData = this.connectingClients[clientId];
      // TODO(flackr): Maybe unbind the listeners?
      delete this.connectingClients[clientId];
      this.onconnection(clientData.rtc, clientData.dataChannel);
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
  };

  return Host;
}();