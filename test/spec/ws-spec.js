describe('circ.test.MockWebSocketServer', function() {

  var wss;
  var connection;

  beforeEach(function() {
    installWebSocketMock();
    var WebSocketServer = require('ws').Server;
    wss = new WebSocketServer({ port: 8080 });
  });
  
  afterEach(function() {
    uninstallWebSocketMock();
  });
  
  it('can connect a client', function(done) {
    var serverConnected = false;
    wss.on('connection', function(ws) {
      serverConnected = true;
    });

    var client = new WebSocket('ws://localhost:8080');
    client.addEventListener('open', function() {
      expect(serverConnected).toBe(true);
      done();
    });
  })
  
  describe('with a connected client', function() {
    var clientWS;
    var serverWS;
    
    beforeEach(function(done) {
      wss.on('connection', function(ws) {
        expect(ws).toBeTruthy();
        serverWS = ws;
      });
      clientWS = new WebSocket('ws://localhost:8080');
      clientWS.addEventListener('open', function() {
        expect(serverWS).toBeTruthy();
        done();
      });
    })
    
    it('can send and receive messages', function(done) {
      var clientMessage = 'ping';
      var serverMessage = 'pong';
      serverWS.on('message', function(msg) {
        expect(msg).toEqual(clientMessage);
        serverWS.send(serverMessage);
      });
      clientWS.addEventListener('message', function(e) {
        expect(e.data).toEqual(serverMessage);
        done();
      });
      clientWS.send(clientMessage);
    });
    
    it('can detect server closed', function(done) {
      clientWS.addEventListener('close', function() {
        done();
      });
      serverWS.close();
    });

    it('can detect client closed', function(done) {
      serverWS.on('close', function() {
        done();
      });
      clientWS.close();
    });
  });
  
});