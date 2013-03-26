// Generated by CoffeeScript 1.4.0
(function() {
  "use strict";
  var ChromeSocket, exports, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  exports = (_ref = window.mocks) != null ? _ref : window.mocks = {};

  ChromeSocket = (function(_super) {

    __extends(ChromeSocket, _super);

    ChromeSocket.useMock = function() {
      return net.ChromeSocket = ChromeSocket;
    };

    function ChromeSocket() {
      ChromeSocket.__super__.constructor.apply(this, arguments);
    }

    ChromeSocket.prototype.connect = function(host, port) {};

    ChromeSocket.prototype.write = function(data) {
      var _this = this;
      this._active();
      return irc.util.fromSocketData(data, (function(msg) {
        return _this.received(msg);
      }));
    };

    ChromeSocket.prototype.close = function() {
      return this.emit('close', 'socket error');
    };

    ChromeSocket.prototype.received = function(msg) {
      return this.emit('drain');
    };

    ChromeSocket.prototype.respond = function() {
      var args, type;
      type = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      this._active();
      return this.emit.apply(this, [type].concat(__slice.call(args)));
    };

    ChromeSocket.prototype.respondWithData = function(msg) {
      var _this = this;
      this._active();
      msg += '\r\n';
      return irc.util.toSocketData(msg, (function(data) {
        return _this.respond('data', data);
      }));
    };

    return ChromeSocket;

  })(net.AbstractTCPSocket);

  exports.ChromeSocket = ChromeSocket;

}).call(this);
