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
        done();
        //client.join('#join').then(function(details) {
            // TODO(flackr): Expect things on details.});
        //})
      });
    });
  });

  afterEach(function() {
    uninstallWebRTCMock();
    uninstallWebSocketMock();
    uninstallXMLHttpRequestMock();
  });

});