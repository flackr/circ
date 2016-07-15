function MockClient() {
}

MockClient.prototype = {
  send: function(hostId, server, message) {},
  join: function(hostId, server, channel) {},
  connect: function(hostId, address, port, password) {},
};