/* global circ */
// TODO(flackr): Use listeningPorts to bind the mock server to the correct fake local port.
var listener = null;
var listeningPorts = {};

function XMLHttpRequestMock() {
  this.addEventTypes(['load', 'error', 'loadend']);
  this.readyState = 0;
  this.method = '';
  this.address = '';
  this.server_ = null;
  this.async = true;
}

XMLHttpRequestMock.prototype = circ.util.extend(circ.util.EventSource.prototype, {
  open: function(method, address, is_async) {
    this.readyState = 1;
    this.method = method;
    this.address = address;
    this.async = is_async;
  },
  send: function(data) {
    this.data = data;
    if (this.readyState != 1)
      return;
    var req = {url: this.address.match(/^(?:[^/]*\/){2}[^/]*(.*)/)[1]};
    setTimeout(listener.handler_.bind(listener, req, new XMLHttpRequestMockServer(this)), 0);
  },
});

function XMLHttpRequestMockServer(client) {
  this.request_ = client;
}

XMLHttpRequestMockServer.prototype = circ.util.extend(circ.util.EventSource.prototype, {
  setHeader: function(name, value) {
  },
  writeHead: function(resultCode, headers) {
    // TODO: Do something with 'Content-type' header.
    this.request_.readyState = 2;
    this.request_.responseCode = resultCode;
    this.request_.responseType = headers['Content-Type'] || 'application/text';
  },
  end: function(msg) {
    // TODO: Set other response types appropriately.
    if (this.request_.responseType == 'application/json') {
      this.request_.response = JSON.parse(msg);
    } else {
      this.request_.responseText = msg;
    }
    this.request_.readyState = 4;
    if (this.request_.responseCode == 200)
      this.request_.dispatchEvent('load');
    else
      this.request_.dispatchEvent('error');
      // loadend is dispatched regardless of the result.
    this.request_.dispatchEvent('loadend');
  },
});

function WebSocketClientMock(address, origin) {
  this.addEventTypes(['open', 'message', 'close']);
  this.ws_ = null;
  this.readyState = 0;
  this.address = address;
  this.origin_ = origin;
  // Need to give the caller a chance to attach listeners.
  setTimeout(listener.onConnection.bind(listener, this), 0);
}

WebSocketClientMock.prototype = circ.util.extend(circ.util.EventSource.prototype, {
  send: function(msg) {
    this.ws_.dispatch('message', msg);
  },
  onConnection: function(ws) {
    this.ws_ = ws;
    this.readyState = 1;
    var self = this;
    setTimeout(function() {
      self.dispatchEvent('open');
    }, 0);
  },
  close: function() {
    if (this.readyState == 3)
      return;
    this.ws_.readyState = 2;
    this.ws_.dispatch('close');
    this.ws_.readyState = 3;
    this.ws_.ws = null;
    this.ws_ = null;
    this.readyState = 3;
  },
});

window.originalXMLHttpRequest = window.XMLHttpRequest;
function installXMLHttpRequestMock() {
  window.XMLHttpRequest = XMLHttpRequestMock;
  window.XMLHttpRequest.prototype = XMLHttpRequestMock.prototype;
}

function uninstallXMLHttpRequestMock() {
  window.XMLHttpRequest = originalXMLHttpRequest;
  window.XMLHttpRequest.prototype = originalXMLHttpRequest.prototype;
}

window.originalWebSocket = window.WebSocket;
function installWebSocketMock() {
  window.WebSocket = WebSocketClientMock;
  window.WebSocket.prototype = WebSocketClientMock.prototype;
}

function uninstallWebSocketMock() {
  window.WebSocket = window.originalWebSocket;
  window.WebSocket.prototype = window.originalWebSocket.prototype;
}

packages['ws'] = (function() {
  
  function WebSocketServerMock(obj) {
    if (obj) {
      if (obj.server) {
        this.server = obj.server;
        this.server.webSocketServer = this;
        this.port = this.server.port;
      } else if (obj.port) {
        this.port = obj.port;
        listener = this;
        listeningPorts[this.port] = this;
      }
    }
  }
  
  WebSocketServerMock.prototype = circ.util.extend(NodeJSEventSource.prototype, {
    attach: function(httpServer) {
      httpServer.onConnection = this.onConnection.bind(this);
    },
    onConnection: function(ws) {
      var connection = new WebSocketServerClientMock(ws);
      this.dispatch('connection', connection);
    },
    
  });
  
  function WebSocketServerClientMock(ws) {
    this.ws = ws;
    this.upgradeReq = {
      url: ws.address.match(/^(?:[^/]*\/){2}[^/]*(.*)/)[1],
      headers: {
        origin: ws.origin_,
      },
    };
    this.readyState = 1;
    this.ws.onConnection(this);
  }
  
  WebSocketServerClientMock.prototype = circ.util.extend(NodeJSEventSource.prototype, {
    send: function(msg) {
      this.ws.dispatchEvent('message', {data: msg});
    },
    close: function() {
      if (this.readyState == 3)
        return;
      this.ws.readyState = 2;
      this.ws.dispatchEvent('close');
      this.ws.readyState = 3;
      this.ws.ws = undefined;
      this.ws = undefined;
      this.readyState = 3;
    }
  });

  function attachToHttpServer(server) {
    console.log('Attempted to attatch to WebSocket Server');
    var mockWsServer = new WebSocketServerMock();
    mockWsServer.attach(server);
    return mockWsServer;
  }
  
  return {
    'Server': WebSocketServerMock,
    'attach': attachToHttpServer,
  };
})();

packages['http'] = (function() {
  function MockHttpServer(handler) {
    this.handler_ = handler;
    this.port = undefined;
  }
  
  MockHttpServer.prototype.listen = function(port) {
    listener = this;
    listeningPorts[port] = this;
    this.port = port;
    return this;
  }
  
  MockHttpServer.prototype.onConnection = function(client) {
    if (client instanceof WebSocketClientMock && this.webSocketServer) {
      this.webSocketServer.onConnection(client);
      return;
    }
    throw new Error('Received unhandled connection from client');
  }
  
  function createMockServer(handler) {
    return new MockHttpServer(handler);
  }
  
  return {
    'createServer': createMockServer,
  }
})();

packages['serve-static'] = (function() {

  return function() {
    console.log('serve-static not actually implemented');
  };
})();
