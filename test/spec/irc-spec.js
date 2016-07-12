describe('circ.CircClient', function() {
  var Server = require('./server.js').Server;
  var CircNode = require('./circ-node.js').CircNode;
  var server;
  var serverAddress = 'http://www.example.com';
  var testPort = '1234';
  var user = 'johndoe';

  beforeEach(function(done) {
    installXMLHttpRequestMock();
    installWebSocketMock();
    installWebRTCMock();
    server = new Server({'port': testPort});
    var request = new XMLHttpRequest();
    request.open('GET', serverAddress + '/register/' + user, true);
    request.addEventListener('loadend', function() {
      expect(request.responseCode).toBe(200);
      done();
    });
    request.send();
  });
  
  describe('connected host', function(done) {
    var host;
    var client;
    var hostId;
    var ircServer;

    beforeEach(function(done) {
      ircServer = new IRCServer('irc.server', 6667);
      host = new CircNode(serverAddress, user);
      host.host.onopen = function() {
        connectClient();
      };
      
      var connectClient = function() {
        client = new circ.CircClient(serverAddress, user);
        client.addEventListener('connection', function(actualHostId) {
          hostId = actualHostId;
          done();
        });
      }
    });
    
    it('can join a server', function(done) {
      client.connect(hostId, 'irc.server', 6667).then(function() {
        client.join(hostId, 'irc.server', '#join').then(function(details) {
          done();
        })
      });
    });
    
    it('can join a named server', function(done) {
      client.connect(hostId, 'irc.server', 6667, {'name': 'test server'}).then(function() {
        client.join(hostId, 'test server', '#join').then(function(details) {
          done();
        })
      });
    });
    
    describe('connected to channel', function() {
      beforeEach(function(done) {
        client.connect(hostId, 'irc.server', 6667, {'name': 'test server'})
          .then(function() { return client.join(hostId, 'test server', '#join'); })
          .then(done);
      });
      
      it('can send a message to a server', function(done) {
        client.send(hostId, 'test server', 'some message').then(done);
      });
      
      it('can send multiple messages', function(done) {
        Promise.all([0, 1].map(function(e) {
          return client.send(hostId, 'test server', 'some message');
        })).then(done);
      });
      
      it('does not send to nonexistent servers', function(done) {
        client.send(hostId, 'nonexistent server', 'some message').then(function() {
          fail('The message should not have been sent.');
        }, done);
      });
    });
  });

  afterEach(function() {
    uninstallWebRTCMock();
    uninstallWebSocketMock();
    uninstallXMLHttpRequestMock();
  });

});