setName('auto_identify');
setDescription('hides NickServ password and automatically identifies on startup');

send('hook_message', 'privmsg');
loadFromStorage();

// Keeps track of the last NickServ password used in each server.
var serverPasswords = {};

this.onMessage = function(e) {
  if (e.type == 'system' && e.name == 'loaded' && e.args[0]) {
    updatePasswords(e.args[0]);
  } else if (e.type == 'message' && e.name == 'privmsg') {
    handlePrivateMessage(e);
  } else {
    propagate(e);
  }
};

var handlePrivateMessage = function(event) {
  var source = event.args[0];
  var message = event.args[1];
  if (source.toLowerCase() != 'nickserv') {
    propagate(event);
  } else if (shouldAutoIdentify(event.context, message)) {
    propagate(event);
    autoIdentify(event.context, message);
  } else if (nickServPasswordIsVisible(message)) {
    propagate(event, 'none');
    snoopPassword(event.context, message);
    hideNickServPassword(event);
  } else {
    propagate(event);
  }
};

var shouldAutoIdentify = function(context, message) {
  return message.indexOf('nickname is registered') >= 0 &&
      serverPasswords[context.server];
};

var autoIdentify = function(context, message) {
  var pw = serverPasswords[context.server];
  send(context, 'message', 'notice', 'Automatically identifying nickname with NickServ...');
  send(context, 'command', 'raw', 'PRIVMSG', 'NickServ', '"identify', pw + '"');
};

var nickServPasswordIsVisible = function(message) {
  var words = message.split(' ');

  // Handle both "/msg NickServ IDENTIFY user pass" and
  // "/msg NickServ IDENTIFY pass"
  return ((words.length == 1 || words.length == 2) &&
          words[0].toLowerCase() == 'identify');
};

var snoopPassword = function(context, message) {
  var password = message.split(' ')[1];
  serverPasswords[context.server] = password;
  saveToStorage(serverPasswords);
};

var hideNickServPassword = function(event) {
  var words = event.args[1].split(' ');
  words[1] = getHiddenPasswordText(words[1].length);
  event.args[1] = words.join(' ');
  sendEvent(event);
};

var getHiddenPasswordText = function(length) {
  var hiddenPasswordText = '';
  for (var i = 0; i < length; i++) {
    hiddenPasswordText += '*';
  }
  return hiddenPasswordText;
};

var updatePasswords = function(loadedPasswords) {
  for (var server in loadedPasswords) {
    if (!serverPasswords[server]) {
      serverPasswords[server] = loadedPasswords[server];
    }
  }
};
