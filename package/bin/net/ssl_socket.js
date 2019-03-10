(function() {
  "use strict";
  var SslSocket, exports, _ref,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  var exports = (_ref = window.net) != null ? _ref : window.net = {};

  /*
   * A socket connected to an IRC server. Uses chrome.sockets.tcp.
  */


  SslSocket = (function(_super) {

    __extends(SslSocket, _super);

    function SslSocket() {
      this._onCreate = __bind(this._onCreate, this);
      this._onConnect = __bind(this._onConnect, this);
      this._onSecure = __bind(this._onSecure, this);
      this._onReceive = __bind(this._onReceive, this);
      this._onReceiveError = __bind(this._onReceiveError, this);
      return SslSocket.__super__.constructor.apply(this, arguments);
    }

    SslSocket.prototype.connect = function(addr, port) {
      this._active();
      var _this = this;
      return chrome.sockets.tcp.create({}, function(si) {
        _this._onCreate(si, addr, parseInt(port))
      });
    };

    SslSocket.prototype._onCreate = function(si, addr, port) {
      var self = this;
      this.socketId = si.socketId;
      if (this.socketId > 0) {
        registerSocketConnection(si.socketId);
        chrome.sockets.tcp.setPaused(this.socketId, true, function(rc) {
          chrome.sockets.tcp.connect(
              self.socketId, addr, port, self._onConnect);
        });
      } else {
        return this.emit('error', "couldn't create socket");
      }
    };

    SslSocket.prototype._onConnect = function(rc) {
      if (rc < 0) {
        this.emit('error', "couldn't connect to socket: " +
          chrome.runtime.lastError.message + " (error " + (-rc) + ")");
      } else {
        chrome.sockets.tcp.secure(this.socketId, {}, this._onSecure);
      }
    };

    SslSocket.prototype._onSecure = function(rc) {
      if (rc < 0) {
        this.emit('error', "failed to secure socket: " +
          chrome.runtime.lastError.message + " (error " + (-rc) + ")");
        return;
      }
      this.emit('connect');

      chrome.sockets.tcp.onReceive.addListener(this._onReceive);
      chrome.sockets.tcp.onReceiveError.addListener(this._onReceiveError);
      chrome.sockets.tcp.setPaused(this.socketId, false);
    };

    SslSocket.prototype._onReceive = function(info) {
      if (info.socketId != this.socketId)
        return;
      this._active();
      this.emit('data', info.data);
    };

    SslSocket.prototype._onReceiveError = function(info) {
      if (info.socketId != this.socketId)
        return;
      this._active();
      if (info.resultCode == -100) {  // connection closed
        this.emit('end');
        this.close();
      }
      else {
        this.emit('error', "read from socket: " + 
          " (error " + (-info.resultCode) + ")");
        this.close();
      }
    };

    SslSocket.prototype.write = function(data) {
      var _this = this;
      this._active();
      return chrome.sockets.tcp.send(this.socketId, data, function(sendInfo) {
        if (sendInfo.resultCode < 0) {
          console.error("SOCKET ERROR on send: ",
            chrome.runtime.lastError.message + " (error " + (-sendInfo.resultCode) + ")");
        }
        if (sendInfo.bytesSent === data.byteLength) {
          return _this.emit('drain');
        } else {
          if (sendInfo.bytesSent >= 0) {
            console.error("Can't handle non-complete send: wrote " +
              sendInfo.bytesSent + " expected " + data.byteLength);
          }
          return _this.emit('error',
              "Invalid send on socket, code: " + sendInfo.bytesSent);
        }
      });
    };

    SslSocket.prototype.close = function() {
      if (this.socketId != null) {
        chrome.sockets.tcp.onReceive.removeListener(this._onReceive);
        chrome.sockets.tcp.onReceiveError.removeListener(this._onReceiveError);
        chrome.sockets.tcp.disconnect(this.socketId);
        chrome.sockets.tcp.close(this.socketId);
        registerSocketConnection(this.socketId, true);
      }
      return this.emit('close');
    };

    return SslSocket;

  })(net.AbstractTCPSocket);

  exports.SslSocket = SslSocket;

}).call(this);
