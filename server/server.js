/**
 * CIRC server helps connect clients to hosts.
 */
exports.Server = function() {
  var http = require('http');
  var https = require('https');
  var WebSocketServer = require('ws').Server;
  var finalhandler = require('finalhandler');
  var serveStatic = require('serve-static');
  var OAuth2 = require('google-auth-library').prototype.OAuth2;

  var Server = function(options) {
    // TODO(flackr): Load users from disk / database.
    this.users = {};
    this.sessions = {};
    this.nextId_ = 1;
    this.authenticator = null;
    if (process.env.AUTH_CLIENT_SECRET) {
      this.authenticator = new OAuth2('143277396652-uibcos8vorqf1ouls7eom9po0cftjgl8.apps.googleusercontent.com',
                                      process.env.AUTH_CLIENT_SECRET, '' /* redirect_uri */);
    }
    if (!this.authenticator)
      console.warn('Warning: Running without authentication support');
    options.port = options.port || (options.key ? 443 : 80);
    if (options.key)
      this.webServer_ = https.createServer(options, this.onRequest_.bind(this));
    else
      this.webServer_ = http.createServer(this.onRequest_.bind(this));
    this.webSocketServer_ = new WebSocketServer({'server': this.webServer_});
    this.webSocketServer_.on('connection', this.onConnection_.bind(this));
    this.webServer_.listen(options.port);
    this.serve = serveStatic('../');
    console.log('Listening on ' + options.port);
  };

  Server.prototype = {

    onRequest_: function(req, res) {
      console.log('Request for ' + req.url);
      if (req.url.substring(0, 10) == '/register/') {
        this.registerUser(req, res);
      } else {
        // Default handler.
        var done = finalhandler(req, res);
        this.serve(req, res, done);
      }
    },

    registerUser: function(req, res) {
      var name = req.url.substring(10);
      if (!name) {
        res.writeHead(404);
        res.end();
        return;
      }
      res.writeHead(200, {'Content-Type': 'application/json'});
      if (this.users[name]) {
        res.end(JSON.stringify({'type': 'error', 'error': 404, 'errorText': 'User already exists'}));
        return;
      }
      this.users[name] = {
        'name': name,
      }
      res.end(JSON.stringify({'type': 'success'}));
    },

    /**
     * Dispatched when a client connects to a websocket.
     *
     * @param {WebSocket} websocket A connected websocket client connection.
     */
    onConnection_: function(websocket) {
      // Origin is of the form 'https://www.lobbyjs.com'
      var origin = websocket.upgradeReq.headers.origin || 'unknown';
      var parts = websocket.upgradeReq.url.split('/', 2);
      console.log('connection for ' + origin);
      var action = parts[1];
      if (!action) {
        websocket.send(JSON.stringify({'type': 'error', 'error': 404, 'errorText': 'Invalid request URL'}));
        websocket.close();
        return;
      }
      this.authenticate_(websocket, action);
    },

    authenticate_: function(websocket, action) {
      // TODO(flackr): Time out the connection if the credentials aren't sent.
      // The first message should contain the authentication details.
      var authenticated, continueWithUser;
      websocket.once('message', function(authTokenId) {
        if (this.authenticator) {
          this.authenticator.verifyIdToken(authTokenId, process.env.AUTH_CLIENT_ID, authenticated);
        } else {
          // In tests, we let the user be specified directly.
          continueWithUser(authTokenId);
        }
      }.bind(this));

      authenticated = function(err, login) {
        if (err) {
          // TODO(flackr): Send an error message.
          websocket.close();
          return;
        }
        continueWithUser(login.getUserId());
      }.bind(this);

      continueWithUser = function(user) {
        this.users[user] = this.users[user] || {
          // TODO(flackr): Insert name here?
          'name': user,
        }
        // TODO(flackr): Create the user if it doesn't exist.
        if (action == 'connect') {
          this.connectClient_(websocket, this.users[user]);
        } else if (action == 'host') {
          this.createNode_(websocket, this.users[user]);
        } else {
          websocket.send(JSON.stringify({'type': 'error', 'error': 404, 'errorText': 'Unrecognized action ' + action}));
          console.log('Unrecognized action ' + action);
          websocket.close();
        }
      }.bind(this);
    },

    /**
     * Connect client on |websocket| to host specified by connection url.
     *
     * @param {WebSocket} websocket A connected websocket client connection.
     */
    connectClient_: function(websocket, user) {
      var broadcast = function(msg) {
        for (var hostId in session.hosts) {
          var socket = session.hosts[hostId].socket;
          if (socket.readyState != 1)
            continue;
          socket.send(msg);
        }
      };

      var self = this;
      var session = this.sessions[user.name];
      console.log('Connecting ' + user.name);

      if (!session || session.hosts.length == 0) {
        console.log("Client attempted to connect to a user with no hosts.");
        websocket.send(JSON.stringify({'type': 'error', 'error': 404, 'errorText': 'Your user doesn\'t have any connected hosts.'}));
        websocket.close();
        return;
      }

      var clientId = session.nextClientId++;
      session.clients[clientId] = {
        'socket': websocket
      };
      console.log("Client " + user.name + " attempting to connect to session");

      websocket.on('message', function(message) {
        if (!session) {
          console.log("Client attempted to deliver a message on ended session.");
          websocket.send(JSON.stringify({'error': 404}));
          websocket.close();
          return;
        }
        var data = null;
        try {
          // Do not double JSON.stringify
          data = JSON.parse(message);
        } catch (err) {
        }
        var host = session.hosts[data.host];
        // If the host went away, silently discard the message.
        if (!host)
          return;
        if (data !== null && host.socket.readyState == 1) {
          host.socket.send(JSON.stringify({'client': clientId, 'type': data.type, 'data': data.data}));
        } else {
          console.log("Client message is not JSON or host does not exist: " + message);
          websocket.close();
        }
      });
      websocket.on('close', function() {
        console.log('client ' + clientId + ' disconnected.');
        delete session.clients[clientId];
        // TODO(flackr): Test if this is called sychronously when host socket
        // closes, if so remove.
        console.log('Client ' + clientId + ' closing connection');
        broadcast(JSON.stringify({
            'client': clientId,
            'type': 'close'}));
      });
      // Inform the server that a client connected.
      // broadcast(JSON.stringify({'client': clientId}));

      // Let the client know what hosts exist.
      var hostIds = [];
      for (var hostId in session.hosts) {
        hostIds.push(hostId);
      }
      websocket.send(JSON.stringify({'type': 'hosts', 'hosts': hostIds}));
    },

    /**
     * Create a new session host accepting connections through signaling socket
     * |websocket|.
     *
     * @param {WebSocket} websocket A connected websocket client connection.
     */
    createNode_: function(websocket, user) {
      var self = this;
      var origin = websocket.upgradeReq.headers.origin || 'unknown';
      var session = this.sessions[user.name] = this.sessions[user.name] || {
        'hosts': {},
        'clients': {},
        'nextClientId': 1,
        'nextHostId': 1,
        'hostCount': 0,
      };
      var hostId = String(session.nextHostId++);
      session.hosts[hostId] = {
        'socket': websocket,
      };
      session.hostCount++;

      // Could broadcast to active clients, but this seems like overkill. There's
      // no need for connecting clients to know about newly added hosts.
      websocket.on('message', function(message) {
        var data;
        try {
          data = JSON.parse(message);
        } catch (err) {
          websocket.close();
          return;
        }
        var clientId = data.client;
        var client = session.clients[clientId];
        if (!client) {
          websocket.send(JSON.stringify({
            'error': 0,
            'message': 'Client does not exist.'}));
          return;
        }
        if (client.socket.readyState == 1)
          client.socket.send(JSON.stringify({'type':data.type, 'host': hostId, 'data':data.data}));
      });
      websocket.on('close', function() {
        console.log("Host " + hostId + " left.");

        delete session.hosts[hostId];
        session.hostCount--;

        for (var clientId in session.clients) {
          // Server went away while client was connecting.
          if (session.clients[clientId].socket.readyState == 1) {
            session.clients[clientId].socket.send(JSON.stringify({'host': hostId, 'type': 'close'}));
          }

          // Close client connections if the last host went away.
          if (session.hostCount == 0)
            session.clients[clientId].socket.close();
        }
        if (session.hostCount == 0) {
          delete self.sessions[user.name];
        }
      });
      console.log('Created session ' + hostId);
      websocket.send(hostId);
    },

    /**
     * Shuts down the signaling server for game sessions.
     */
    shutdown: function() {
      this.webSocketServer_.close();
    },

  };

  return Server;
}();
