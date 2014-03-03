(function() {
  "use strict";
  var RemoteDevice, exports, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  var exports = (_ref = window.mocks) != null ? _ref : window.mocks = {};

  RemoteDevice = (function(_super) {

    __extends(RemoteDevice, _super);

    RemoteDevice.useMock = function() {
      window.RemoteDevice = RemoteDevice;
      window.chrome.sockets = {};
      window.chrome.sockets.tcp = {};
      window.chrome.sockets.tcp.create = function() {};
      window.chrome.sockets.tcpServer = {};
      window.chrome.sockets.tcpServer.listen = function () { };
      this.state = 'finding_port';
      this.willConnect = true;
      this.devices = [];
      this.onConnect = function(callback) {
        return callback(RemoteDevice.willConnect);
      };
      return this.sendAuthentication = function() {};
    };

    RemoteDevice.prototype.equals = function(o) {
      return (o != null ? o.id : void 0) === this.id;
    };

    RemoteDevice.prototype.usesConnection = function(connectionInfo) {
      return connectionInfo.addr === this.addr && connectionInfo.port === this.port;
    };

    RemoteDevice.prototype.getState = function() {
      return RemoteDevice.state;
    };

    function RemoteDevice(addr, port) {
      var _ref1, _ref2;
      this.addr = addr;
      this.port = port;
      RemoteDevice.__super__.constructor.apply(this, arguments);
      this.id = (_ref1 = this.addr) != null ? _ref1 : RemoteDevice.devices.length;
      if ((_ref2 = this.addr) == null) {
        this.addr = '1.1.1.' + (RemoteDevice.devices.length + 1);
      }
      RemoteDevice.devices.push(this);
    }

    RemoteDevice.getOwnDevice = function(callback) {
      var device;
      device = new RemoteDevice('1.1.1.1');
      device.possibleAddrs = ['1.1.1.1'];
      return callback(device);
    };

    RemoteDevice.prototype.send = function(type) {
      return this.sendType = type;
    };

    RemoteDevice.prototype.listenForNewDevices = function(callback) {
      return RemoteDevice.onNewDevice = callback;
    };

    RemoteDevice.prototype.connect = function(callback) {
      return RemoteDevice.onConnect(callback);
    };

    RemoteDevice.prototype.close = function() {};

    return RemoteDevice;

  })(EventEmitter);

  exports.RemoteDevice = RemoteDevice;

}).call(this);
