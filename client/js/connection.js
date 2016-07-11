window.circ = window.circ || {};

circ.ClientSession = function(server, name) {
  this.connectingHosts = 0;
  this.socket = new WebSocket(server + '/' + name + '/connect')
  this.hosts = {};
  this.configuration = {
    iceServers: [
        {urls: "stun:stun.l.google.com:19302"},
    ],
  };
  this.addEventTypes(['connection', 'hosts']);
  this.socket.addEventListener('message', this.onServerMessage_.bind(this));
}

circ.ClientSession.prototype = circ.util.extend(circ.util.EventSource.prototype, {
  onServerMessage_: function(e) {
    var data = JSON.parse(e.data);
    if (data.type == 'hosts') {
      this.dispatchEvent('hosts', data.hosts);
      this.connectingHosts = data.hosts.length;
      for (var i = 0; i < data.hosts.length; i++) {
        var rtc = new RTCPeerConnection(this.configuration, null);
        rtc.onicecandidate = function(hostId, event) {
          if (event.candidate && this.socket.readyState == 1)
            this.socket.send(JSON.stringify({'host': hostId, 'type' : 'candidate', 'data' : event.candidate}));
        }.bind(this, data.hosts[i]);
        // TODO(flackr): Listen to oniceconnectionstatechange for disconnected state during connection process.
        var dataChannel = rtc.createDataChannel('data', null);
        dataChannel.addEventListener('open', this.onHostConnected_.bind(this, data.hosts[i]));
        this.hosts[data.hosts[i]] = {
          'state': 'connecting',
          'rtc': rtc,
          'dataChannel': dataChannel,
        };
        rtc.createOffer(function(hostId, desc) {
          this.hosts[hostId].rtc.setLocalDescription(desc);
          if (this.socket.readyState == 1)
            this.socket.send(JSON.stringify({'host': hostId, 'type': 'offer', 'data': desc}));
        }.bind(this, data.hosts[i]), function(e) {
          console.log('Failed to create offer');
        });
      }
    } else if (data.type == 'answer' && this.hosts[data.host].rtc.signalingState != 'closed') {
      this.hosts[data.host].rtc.setRemoteDescription(new RTCSessionDescription(data.data));
    } else if (data.type == 'candidate' && this.hosts[data.host].rtc.signalingState != 'closed') {
      this.hosts[data.host].rtc.addIceCandidate(new RTCIceCandidate(data.data));
    } else {
      console.error('Unrecognized message type: ' + data.type);
    }
  },
  onHostConnected_: function(hostId) {
    var details = this.hosts[hostId];
    delete this.hosts[hostId];
    this.dispatchEvent('connection', details.rtc, details.dataChannel);
    this.connectingHosts--;
    if (this.connectingHosts == 0) {
      console.log('All hosts connected - disconnecting from server.');
      this.socket.close();
    }
  },
  close: function() {
    this.websocket_.close();
  },
});