var lobby = require("./server.js");

var options = {port: process.env.PORT};

var server = new lobby.Server(options);
server.listen(options);
