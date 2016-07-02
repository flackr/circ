describe('circ.test.MockXMLHttpServer', function() {

  var wss;
  var connection;
  var http = require('http');
  var WebSocketServer = require('ws').Server;

  beforeEach(function() {
    installXMLHttpRequestMock();
  });
  
  afterEach(function() {
    uninstallXMLHttpRequestMock();
  });
  
  it('can respond to a request', function(done) {
    var server = http.createServer(function(req, res) {
      expect(req.url = '/ping');
      res.writeHead(200, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({'response': 'pong'}));
    });
    server.listen(8080);
    var request = new XMLHttpRequest();
    request.open('GET', 'http://localhost:8080/ping', true);
    request.addEventListener('load', function() {
      expect(request.responseCode).toBe(200);
      expect(request.response.response).toBe('pong');
      done();
    });
    request.send();
  });
});