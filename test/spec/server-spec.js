describe('circ.Server', function() {

  var server;
  var testPort = '1234';

  beforeEach(function() {
    installXMLHttpRequestMock();
    installWebSocketMock();
    installWebRTCMock();
    server = new Server({'port': testPort});
  });

  afterEach(function() {
    uninstallWebRTCMock();
    uninstallWebSocketMock();
    uninstallXMLHttpRequestMock();
  });

  it("can create a user", function(done) {
    expect(server.users['johndoe']).toBe(undefined);
    var request = new XMLHttpRequest();
    request.open('GET', '/register/johndoe', true);
    request.addEventListener('loadend', function() {
      expect(request.responseCode).toBe(200);
      expect(request.response.type).toBe('success');
      expect(server.users['johndoe'].name).toBe('johndoe');
      done();
    });
    request.send();
  });

  it("rejects a host for an unknown user", function(done) {
    var host = new WebSocket('wss://circ-server.com/foobar/host');
    var receivedError = false;
    host.addEventListener('message', function(e) {
      expect(JSON.parse(e.data).type).toBe('error');
      receivedError = true;
    });
    host.addEventListener('close', function() {
      done();
    });
  });

  describe("with a user and a couple hosts", function(done) {
    var hosts = [];

    beforeEach(function(done) {
      hosts[0] = new WebSocket('wss://circ-server.com/test/host');
      hosts[1] = new WebSocket('wss://circ-server.com/test/host');
      var connected = 0;
      var hostConnected = function() {
        if (++connected == 2)
          done();
      };
      for (var i = 0; i < 2; i++) {
        hosts[i].addEventListener('open', hostConnected);
      }
      server.users['test'] = {'name': 'test'};
    });

    afterEach(function() {
      hosts[0].close();
      hosts[1].close();
      delete server.users['test'];
    });

    it("can send exchange messages with both hosts", function(done) {
      var totalNegotiations = 0;
      var negotiations = [false, false];
      var hostArry;
      var client = new WebSocket('wss://circ-server.com/test/connect');
      client.addEventListener('message', function(e) {
        var data = JSON.parse(e.data);
        if (data.type == 'hosts') {
          hostArry = data.hosts;
          expect(data.hosts.length).toBe(2);
          for (var i = 0; i < data.hosts.length; i++) {
            client.send(JSON.stringify({'host': data.hosts[i], 'type': 'offer', 'data': 'offer' + i}));
          }
        } else if (data.type == 'answer') {
          var idx = hostArry.indexOf(data.host);
          expect(idx).toBeGreaterThan(-1);
          expect(negotiations[idx]).toBe(false);
          negotiations[idx] = true;
          expect(data.data).toBe('answer' + idx);
          if (++totalNegotiations == 2)
            done();
        }
      });
      for (var i = 0; i < 2; i++) {
        hosts[i].addEventListener('message', function(idx, e) {
          var data = JSON.parse(e.data);
          if (data.type == 'offer') {
            expect(data.data).toBe('offer' + idx);
            hosts[idx].send(JSON.stringify({'client': data.client, 'type': 'answer', 'data': 'answer' + idx}));
          }
        }.bind(null, i));
      }
    });
  });
});