
circ.ClientSession = function(server, name) {
  this.socket = new WebSocket(server + '/' + name + '/connect')
  this.state = 'connecting';
  this.configuration = {
    iceServers: [
        {urls: "stun:stun.l.google.com:19302"},
    ],
  };
  this.addEventTypes(['open', 'message', 'close', 'state', 'error']);
  if (window.RTCPeerConnection) {
    this.rtcConnection_ = new RTCPeerConnection(this.configuration, null);
    this.dataChannel_ = this.rtcConnection_.createDataChannel('data', null);
    this.dataChannel_.addEventListener('open', this.onDataChannelConnected_.bind(this, this.dataChannel_));
    this.dataChannel_.addEventListener('message', this.onDataChannelMessage_.bind(this));
    this.rtcConnection_.onicecandidate = this.onIceCandidate_.bind(this);
    this.rtcConnection_.oniceconnectionstatechange = this.onIceConnectionStateChange_.bind(this);
  }
  this.websocket_ = new WebSocket(host + '/' + identifier);
  this.websocket_.addEventListener('open', this.onOpen_.bind(this));
  this.websocket_.addEventListener('message', this.onMessage_.bind(this));
  this.websocket_.addEventListener('close', this.onWebSocketClose_.bind(this));
}

circ.ClientSession.prototype = circ.util.extend(circ.util.EventSource.prototype, {
  changeState: function(state) {
    if (state == this.state)
      return false;
    this.state = state;
    this.dispatchEvent('state', state);
    return true;
  },
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
  onMessage_: function(e) {
    var data = JSON.parse(e.data);
    if (data.type == 'error') {
      this.dispatchEvent('error', data.error, data.errorText || '');
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