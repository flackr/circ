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
    var data = String.fromCharCode.apply(null, new Uint8Array(buf));
    callback(data);
  };

  var SslSocket = function() {
    this._buffer = '';
    this._requiredBytes = 0;
    net.AbstractTCPSocket.apply(this);
  };

  SslSocket.prototype.__proto__ = net.AbstractTCPSocket.prototype;

  SslSocket.prototype.connect = function(addr, port) {
    var _this = this;
    this._active();
    chrome.socket.create('tcp', {}, function(si) {
      _this.socketId = si.socketId;
      if (_this.socketId > 0) {
        registerSocketConnection(si.socketId);
        // Port will be of the form +port# given that it is using SSL.
        chrome.socket.connect(_this.socketId, addr, parseInt(port.substr(1)),
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
    chrome.socket.read(this.socketId, this._onRead.bind(this));
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
            chrome.socket.write(_this.socketId, data, function(writeInfo) {
              if (writeInfo.resultCode < 0) {
                console.error('SOCKET ERROR on write: ' +
                    chrome.runtime.lastError.message + ' (error ' + (-writeInfo.resultCode) + ')');
              }
              if (writeInfo.bytesWritten === data.byteLength) {
                _this.emit('drain');
              } else {
                if (writeInfo.bytesWritten >= 0) {
                  console.error('Can\'t handle non-complete writes: wrote ' +
                      writeInfo.bytesWritten + ' expected ' + data.byteLength);
                }
                _this.emit('error', 'Invalid write on socket, code: ' + writeInfo.bytesWritten);
              }
            });
          });
        },
        dataReady: function(c) {
          // indicate application data is ready
          var data = forge.util.decodeUtf8(c.data.getBytes());
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
      chrome.socket.disconnect(this.socketId);
      chrome.socket.destroy(this.socketId);
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

  SslSocket.prototype._onRead = function(readInfo) {
    if (readInfo.resultCode === -1) {
      console.error('Bad assumption: got -1 in _onRead');
    }
    this._active();
    if (readInfo.resultCode < 0) {
      var message = '';
      if (chrome.runtime.lastError)
        message = chrome.runtime.lastError.message;
      this.emit('error', 'read from socket: ' + message + ' (error ' +
          (-readInfo.resultCode) + ')');
      return;
    } else if (readInfo.resultCode === 0) {
      this.emit('end');
      this._close();
    }
    if (readInfo.data.byteLength) {
      if (!this._tls.open)
        return;
      var _this = this;
      arrayBuffer2String(readInfo.data, function(data) {
        _this._buffer += data;
        if (_this._buffer.length >= _this._requiredBytes) {
          _this._requiredBytes = _this._tls.process(_this._buffer);
          _this._buffer = '';
        }
        chrome.socket.read(_this.socketId, _this._onRead.bind(_this));
      });
    }
  };

  return SslSocket;
})();
