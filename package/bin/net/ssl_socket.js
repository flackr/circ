window.net.SslSocket = (function() {

  function createBlob(src) {
    var BB = window.BlobBuilder || window.WebKitBlobBuilder;
    if (BB) {
      var bb = new BB();
      bb.append(src);
      return bb.getBlob();
    }
    return new Blob([src]);
  }

  var string2ArrayBuffer = function(string, callback) {
    var buf = new ArrayBuffer(string.length);
    var bufView = new Uint8Array(buf);
    for (var i=0; i < string.length; i++) {
      bufView[i] = string.charCodeAt(i);
    }
    callback(buf);
  };

  var arrayBuffer2String = function(buf, callback) {
    var bufView = new Uint8Array(buf);
    var chunkSize = 65536;
    var result = '';
    for (var i = 0; i < bufView.length; i += chunkSize) {
      result += String.fromCharCode.apply(null, bufView.subarray(i, Math.min(i + chunkSize, bufView.length)));
    }
    callback(result);
  };

  var SslSocket = function() {
    this._buffer = '';
    this._requiredBytes = 0;
    this._onReceive = this._onReceive.bind(this);
    this._onReceiveError = this._onReceiveError.bind(this);
    net.AbstractTCPSocket.apply(this);
  };

  SslSocket.prototype.__proto__ = net.AbstractTCPSocket.prototype;

  SslSocket.prototype.connect = function(addr, port) {
    var _this = this;
    this._active();
    chrome.sockets.tcp.create({}, function(si) {
      _this.socketId = si.socketId;
      if (_this.socketId > 0) {
        registerSocketConnection(si.socketId);
        chrome.sockets.tcp.setPaused(_this.socketId, true);
        // Port will be of the form +port# given that it is using SSL.
        chrome.sockets.tcp.connect(_this.socketId, addr, parseInt(port.substr(1)),
            _this._onConnect.bind(_this));
      } else {
        _this.emit('error', "Couldn\'t create socket");
      }
    });
  };

  SslSocket.prototype._onConnect = function(rc) {
    if (rc < 0) {
      this.emit('error', 'Couldn\'t connect to socket: ' +
          chrome.runtime.lastError.message + ' (error ' + (-rc) + ')');
      return;
    }
    this._initializeTls({});
    this._tls.handshake(this._tlsOptions.sessionId || null);
    chrome.sockets.tcp.onReceive.addListener(this._onReceive);
    chrome.sockets.tcp.onReceiveError.addListener(this._onReceiveError);
    chrome.sockets.tcp.setPaused(this.socketId, false);
  };

  SslSocket.prototype._initializeTls = function(options) {
    var _this = this;
    this._tlsOptions = options;
    this._tls = forge.tls.createConnection({
        server: false,
        sessionId: options.sessionId || null,
        caStore: options.caStore || [],
        sessionCache: options.sessionCache || null,
        cipherSuites: options.cipherSuites || [
          forge.tls.CipherSuites.TLS_RSA_WITH_AES_128_CBC_SHA,
          forge.tls.CipherSuites.TLS_RSA_WITH_AES_256_CBC_SHA],
        virtualHost: options.virtualHost,
        verify: options.verify || function() { return true },
        getCertificate: options.getCertificate,
        getPrivateKey: options.getPrivateKey,
        getSignature: options.getSignature,
        deflate: options.deflate,
        inflate: options.inflate,
        connected: function(c) {
          // first handshake complete, call handler
//          if(c.handshakes === 1) {
            console.log('TLS socket connected');
            _this.emit('connect');
//          }
        },
        tlsDataReady: function(c) {
          // send TLS data over socket
          var bytes = c.tlsData.getBytes();
          string2ArrayBuffer(bytes, function(data) {
            chrome.sockets.tcp.send(_this.socketId, data, function(sendInfo) {
              if (sendInfo.resultCode < 0) {
                console.error('SOCKET ERROR on write: ' +
                    chrome.runtime.lastError.message + ' (error ' + (-sendInfo.resultCode) + ')');
              }
              if (sendInfo.bytesSent === data.byteLength) {
                _this.emit('drain');
              } else {
                if (sendInfo.bytesSent >= 0) {
                  console.error('Can\'t handle non-complete writes: wrote ' +
                      sendInfo.bytesSent + ' expected ' + data.byteLength);
                }
                _this.emit('error', 'Invalid write on socket, code: ' + sendInfo.resultCode);
              }
            });
          });
        },
        dataReady: function(c) {
          // indicate application data is ready
          var data = c.data.getBytes();
          irc.util.toSocketData(data, function(data) {
            _this.emit('data', data);
          });
        },
        closed: function(c) {
          // close socket
          _this._close();
        },
        error: function(c, e) {
          // send error, close socket
          _this.emit('error', 'tlsError: ' + e.message);
          _this._close();
        }
      });
  };

  SslSocket.prototype._onClosed = function() {
    if (this._tls && this._tls.open && this._tls.handshaking) {
      this.emit('error', 'Connection closed during handshake');
    }
  };

  SslSocket.prototype.close = function() {
    if (this._tls)
      this._tls.close();
  };

  SslSocket.prototype._close = function() {
    if (this.socketId != null) {
      chrome.sockets.tcp.onReceive.removeListener(this._onReceive);
      chrome.sockets.tcp.onReceiveError.removeListener(this._onReceiveError);
      chrome.sockets.tcp.disconnect(this.socketId);
      chrome.sockets.tcp.close(this.socketId);
      registerSocketConnection(this.socketId, true);
    }
    this.emit('close');
  };

  SslSocket.prototype.write = function(data) {
    var _this = this;
    arrayBuffer2String(data, function(data) {
      _this._tls.prepare(data);
    });
  };

  SslSocket.prototype._onReceive = function(receiveInfo) {
    if (receiveInfo.socketId != this.socketId)
      return;
    this._active();
    if (!this._tls.open)
      return;
    var _this = this;
    arrayBuffer2String(receiveInfo.data, function (data) {
      _this._buffer += data;
      if (_this._buffer.length >= _this._requiredBytes) {
        _this._requiredBytes = _this._tls.process(_this._buffer);
        _this._buffer = '';
      }
    });
  };

  SslSocket.prototype._onReceiveError = function (readInfo) {
    if (readInfo.socketId != this.socketId)
      return;
    this._active();
    if (info.resultCode === -100) {  // connection closed
      this.emit('end');
      this._close();
    }
    else {
      var message = '';
      if (chrome.runtime.lastError)
        message = chrome.runtime.lastError.message;
      this.emit('error', 'read from socket: ' + message + ' (error ' +
          (-readInfo.resultCode) + ')');
      this._close();
      return;
    }
  };

  return SslSocket;
})();
