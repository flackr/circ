var fs = require("fs");
var constants = require('constants');

var lobby = require("./server.js");

var options = {port: 443,
            ca: fs.readFileSync('intermediate.crt'),
            key: fs.readFileSync('cert.key'),
            cert: fs.readFileSync('cert.crt'),
            dhparam: 'dh2048.pem',
            ciphers: 'AESGCM:ECDH:HIGH:!DH:!RSA+AESGCM:!kSRP:!kPSK:!DSS:!RC4:!eNULL:!ADH:!AECDH:!EXPORT:!MD5:@STRENGTH',
            secureProtocol: 'SSLv23_method',
            secureOptions: constants.SSL_OP_NO_SSLv3 | constants.SSL_OP_NO_SSLv2,};

var server = new lobby.Server();
server.listen(options);
