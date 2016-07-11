var lobby = require("./server.js");

var options = {port: process.env.PORT};

new lobby.Server(options);
