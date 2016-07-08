
circ.ClientSession = function(server, name) {
  this.socket = new WebSocket(server + '/' + name + '/connect')
  this.hosts = {};
  this.configuration = {
    iceServers: [
        {urls: "stun:stun.l.google.com:19302"},
    ],
  };
  this.addEventTypes(['connection', 'hosts']);
  /*
  if (window.RTCPeerConnection) {
    this.rtcConnection_ = new RTCPeerConnection(this.configuration, null);
    this.dataChannel_ = this.rtcConnection_.createDataChannel('data', null);
    this.dataChannel_.addEventListener('open', this.onDataChannelConnected_.bind(this, this.dataChannel_));
    this.dataChannel_.addEventListener('message', this.onDataChannelMessage_.bind(this));
    this.rtcConnection_.onicecandidate = this.onIceCandidate_.bind(this);
    this.rtcConnection_.oniceconnectionstatechange = this.onIceConnectionStateChange_.bind(this);
  }
  */
  this.socket.addEventListener('message', this.onServerMessage_.bind(this));
}

circ.ClientSession.prototype = circ.util.extend(circ.util.EventSource.prototype, {
  onOpen_: function() {
    if (this.rtcConnection_) {
      this.rtcConnection_.createOffer(this.onOffer_.bind(this), function(e) {
        console.log('Failed to create offer');
      });
    }
  },
  onOffer_: function(desc) {
    this.rtcConnection_.setLocalDescription(desc);
    if (this.websocket_ && this.websocket_.readyState == 1)
      this.websocket_.send(JSON.stringify({'type' : 'offer', 'data' : desc}));
  },
  onIceCandidate_: function(event) {
    if (event.candidate && this.websocket_ && this.websocket_.readyState == 1)
      this.websocket_.send(JSON.stringify({'type' : 'candidate', 'data' : event.candidate}));
  },
  onServerMessage_: function(e) {
    var data = JSON.parse(e.data);
    if (data.type == 'hosts') {
      this.dispatchEvent('hosts', data.hosts);
      for (var i = 0; i < data.hosts.length; i++) {
        var rtc = new RTCPeerConnection(this.configuration, null);
        rtc.onicecandidate = function(hostId, event) {
          if (event.candidate && this.socket.readyState == 1)
            this.socket.send(JSON.stringify({'host': hostId, 'type' : 'candidate', 'data' : event.candidate}));
        }.bind(this, data.hosts[i]);
        rtc.oniceconnectionstatechange = this.onIceConnectionStateChange_.bind(this, data.hosts[i]);
        var dataChannel = rtc.createDataChannel('data', null);
        dataChannel.addEventListener('open', this.onHostConnected_.bind(this, data.hosts[i]));
        this.hosts[data.hosts[i]] = {
          'rtc': rtc,
          'dataChannel': dataChannel,
        };
      }
    } else if (data.type == 'answer' && this.rtcConnection_.signalingState != 'closed') {
      this.rtcConnection_.setRemoteDescription(new RTCSessionDescription(data.data));
    } else if (data.type == 'candidate' && this.rtcConnection_.signalingState != 'closed') {
      this.rtcConnection_.addIceCandidate(new RTCIceCandidate(data.data));
    } else if (data.type == 'message') {
      this.dispatchEvent('message', {'data': JSON.parse(data.data)});
    } else if (data.type == 'relay') {
      this.relay_ = true;
      this.changeState('relay');
      this.dispatchEvent('open');
    } else if (data.type == 'close') {
      this.websocket_.close();
      this.onWebSocketClose_();
    }
  },
  onHostConnected_: function(hostId) {
    var details = this.hosts[i];
    this.dispatchEvent('connection', details.rtc, details.dataChannel);
  },
  onWebSocketClose_: function() {
    delete this.websocket_;
    if (!this.isDataChannelConnected_()) {
      if (this.changeState('closed'))
        this.dispatchEvent('close');
      if (this.rtcConnection_ && this.rtcConnection_.signalingState != 'closed') {
        this.rtcConnection_.close();
      }
    }
  },
  onDataChannelConnected_: function(channel) {
    this.changeState('open');
    if (!this.relay_)
      this.dispatchEvent('open');
  },

  onDataChannelMessage_: function(e) {
    this.dispatchEvent('message', e);
  },

  onIceConnectionStateChange_: function() {
    if (this.rtcConnection_.iceConnectionState == 'disconnected' && !this.relay_) {
      if (this.changeState('closed'))
        this.dispatchEvent('close');
    }
  },

  isDataChannelConnected_: function() {
    return this.dataChannel_ && this.dataChannel_.readyState == 'open' && this.rtcConnection_.iceConnectionState != 'disconnected';
  },

  send: function(msg) {
    if (this.dataChannel_ && this.dataChannel_.readyState == 'open')
      this.dataChannel_.send(msg);
    else if (this.websocket_ && this.websocket_.readyState == 1)
      this.websocket_.send(JSON.stringify({'type': 'message', 'data': msg}));
    else
      throw new Error('Trying to send message while not connected');
  },

  close: function() {
    this.rtcConnection_.close();
    if (this.websocket_) {
      this.websocket_.close();
      delete this.websocket_;
    }
  },
});