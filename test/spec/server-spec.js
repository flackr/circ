describe('circ.Server', function() {

  var Server = require('./server.js').Server;
  var server;
  var testPort = '1234';
  var serverAddress = 'http://www.example.com';

  function addOneShotEventListener(obj, type, fn) {
    var listener = function() {
      obj.removeEventListener(type, listener);
      fn.apply(null, Array.prototype.slice.call(arguments, 0));
    };
    obj.addEventListener(type, listener)
  }

  beforeEach(function() {
    installXMLHttpRequestMock();
    installWebSocketMock();
    installWebRTCMock();
    server = new Server();
    server.listen({'port': testPort});
  });

  afterEach(function() {
    uninstallWebRTCMock();
    uninstallWebSocketMock();
    uninstallXMLHttpRequestMock();
  });

  it("can create a user", function(done) {
    expect(server.users['johndoe']).toBe(undefined);
    var request = new XMLHttpRequest();
    request.open('GET', serverAddress + '/register/johndoe', true);
    request.addEventListener('loadend', function() {
      expect(request.responseCode).toBe(200);
      expect(request.response.type).toBe('success');
      expect(server.users['johndoe'].name).toBe('johndoe');
      done();
    });
    request.send();
  });

  describe("with a user and a couple hosts", function(done) {
    var hosts = [];

    beforeEach(function(done) {
      hosts[0] = new WebSocket('wss://circ-server.com/host');
      hosts[1] = new WebSocket('wss://circ-server.com/host');
      var connected = 0;
      var hostConnected = function() {
        this.send('test');
      };
      var listener = function(e) {
        if (++connected == 2) {
          hosts[0].removeEventListener('message', listener);
          hosts[1].removeEventListener('message', listener);
          done();
        }
      };
      for (var i = 0; i < 2; i++) {
        hosts[i].addEventListener('open', hostConnected.bind(hosts[i]));
        addOneShotEventListener(hosts[i], 'message', listener)
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
      var client = new WebSocket('wss://circ-server.com/connect');
      client.addEventListener('open', function(e) {
        client.send('test');
      });
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
