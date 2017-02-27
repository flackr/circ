/* global circ */

var mockListeningSockets = {};

function MockSocket() {
}

MockSocket.prototype = circ.util.extend(NodeJSEventSource.prototype, {
  connect: function(port, address, callback) {
    var server = mockListeningSockets[address][port];
    if (!server)
      throw Error('No server listening on ' + address + ':' + port);
    this.server_ = new MockSocketConnection(this, server);
    setTimeout(callback, 0);
  },
  write: function(data) {
    this.server_.dispatch('data', data);
  },
});

function MockSocketServer(port, address) {
  mockListeningSockets[address] = mockListeningSockets[address] || {};
  mockListeningSockets[address][port] = this;

}

MockSocketServer.prototype = circ.util.extend(NodeJSEventSource.prototype, {

});

function MockSocketConnection(clientSocket, server) {
  this.client_ = clientSocket;
  this.server_ = server;
  this.server_.dispatch('connection', this);
}

MockSocketConnection.prototype = circ.util.extend(NodeJSEventSource.prototype, {
  write: function(data) {
    this.client_.dispatch('data', data);
  },
});

packages['net'] = {
  'connect': function() {
    var socket = new MockSocket();
    socket.connect.apply(socket, arguments);
    return socket;
  },
  'Socket': MockSocket,
};
