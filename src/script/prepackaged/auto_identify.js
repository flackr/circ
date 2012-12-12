setName('auto_identify');
setDescription('snoops /msg NickServ messages and automatically calls /msg NickServ identify <pw>');
send('hook_command', 'msg');
send('hook_message', 'privmsg');

loadFromStorage();

var serverPasswords = {};

var handleOutgoingMessage = function(context, words) {
  if (words.length != 3) { return; }
  if (words[0].toLowerCase() == 'nickserv' &&
      words[1].toLowerCase() == 'identify' &&
      words[2]) {
    serverPasswords[context.server] = words[2];
    saveToStorage(serverPasswords);
  }
};

var handleIncomingMessage = function(context, from, message) {
  if (!from || !message || from != 'NickServ') { return; }
  if (message.indexOf('nickname is registered') >= 0) {
    pw = serverPasswords[context.server];
    send(context, 'message', 'notice', 'Automatically identifying nickname with NickServ...');
    send(context, 'command', 'raw', 'PRIVMSG', 'NickServ', '"identify', pw + '"');
  }
};

onMessage = function(e) {
  propagate(e);
  if (e.type == 'system' && e.name == 'loaded') {
    if (e.args[0]) {
      serverPasswords = e.args[0];
    }
  } else if (e.type == 'command' && e.name == 'msg') {
    handleOutgoingMessage(e.context, e.args);
  } else if (e.type == 'message' && e.name == 'privmsg') {
    if (serverPasswords[e.context.server]) {
      handleIncomingMessage(e.context, e.args[0], e.args[1]);
    }
  }
};
