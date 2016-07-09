describe('circ.ClientSession', function() {
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
  
  describe('connected hosts', function(done) {
    var hosts;

    beforeEach(function(done) {
      hosts = [];
      // Connect two hosts.
      hosts.push(new Host(serverAddress, user));
      hosts.push(new Host(serverAddress, user));
      var connectedHosts = 0;
      hosts[0].onopen = hosts[1].onopen = function() {
        connectedHosts++;
        if (connectedHosts == 2)
          done();
      }
    });
    
    it('can connect a client to both hosts', function(done) {
      var hostConnections = [];
      for (var i = 0; i < hosts.length; i++) {
        hosts[i].onconnection = function(idx, rtc, dc) {
          hostConnections[idx] = {'rtc': rtc, 'dc': dc, 'pingReceived': false};
          dc.addEventListener('message', function(e) {
            expect(e.data).toBe('ping');
            hostConnections[idx].pingReceived = true;
            dc.send('pong');
          })
        }.bind(null, i);
      }
      var client = new circ.ClientSession(serverAddress, user);
      var connections = [];
      var pongs = 0;
      var noclients = 0;
      var callbacks = {
        'hosts': function(hosts) {
          expect(hosts.length).toBe(2);
        },
        'connection': function(rtc, dc) {
          connections.push({'rtc': rtc, 'dc': dc});
          dc.addEventListener('message', callbacks.pong);
          dc.send('ping');
          if (connections.length == 1)
            expect(callbacks.hosts).toHaveBeenCalled();
        },
        'pong': function(e) {
          expect(e.data).toBe('pong');
          pongs++;
          if (noclients == 2 && pongs == 2)
            finishTest();
        },
        'connecting': function(count) {
          if (count == 0) {
            noclients++;
            if (noclients == 2 && pongs == 2)
              finishTest();
          }
        },
      };
      spyOn(callbacks, 'hosts');
      client.addEventListener('hosts', callbacks.hosts);
      client.addEventListener('connection', callbacks.connection);
      hosts[0].onconnecting = hosts[1].onconnecting = callbacks.connecting;
      var finishTest = function() {
        expect(noclients).toBe(2);
        expect(pongs).toBe(2);
        expect(hostConnections[0].pingReceived).toBe(true);
        expect(hostConnections[1].pingReceived).toBe(true);
        expect(hosts[0].connectingClientCount).toBe(0);
        expect(hosts[1].connectingClientCount).toBe(0);
        done();
      };
    });
  });

  afterEach(function() {
    uninstallWebRTCMock();
    uninstallWebSocketMock();
    uninstallXMLHttpRequestMock();
  });

});