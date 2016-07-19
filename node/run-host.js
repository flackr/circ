// Can fetch wrtc binary from https://github.com/js-platform/node-webrtc/issues/248

// TODO(flackr): Accept custom parameters rather than hard-coding. Perhaps
// we should read them from a config file.
// TODO(flackr): Add customizable server location.
var server = 'wss://www.lobbyjs.com/circ';
var user = process.argv[2];

var CircNode = require('./circ-node.js').CircNode;

new CircNode(server, user);
