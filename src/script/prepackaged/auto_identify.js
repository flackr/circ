setName('auto_identify');
setDescription('hides NickServ password and automatically identifies on startup');

send('hook_message', 'privmsg');
loadFromStorage();

// Keeps track of the last NickServ password used in each server.
var serverPasswords = {};

onMessage = function(e) {
  if (e.type == 'system' && e.name == 'loaded' && e.args[0]) {
    updatePasswords(e.args[0]);
  } else if (e.type == 'message' && e.name == 'privmsg') {
    handlePrivateMessage(e);
  }
};

var handlePrivateMessage = function(event) {
  var source = event.args[0];
  var message = event.args[1];
  if (source != 'NickServ') {
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
  pw = serverPasswords[context.server];
  send(context, 'message', 'notice', 'Automatically identifying nickname with NickServ...');
  send(context, 'command', 'raw', 'PRIVMSG', 'NickServ', '"identify', pw + '"');
};

nickServPasswordIsVisible = function(message) {
  words = message.split(' ');
  return words.length == 2 && words[0].toLowerCase() == 'identify';
};

var snoopPassword = function(context, message) {
  password = message.split(' ')[1];
  serverPasswords[context.server] = password;
  saveToStorage(serverPasswords);
};

hideNickServPassword = function(event) {
  words = event.args[1].split(' ');
  words[1] = getHiddenPasswordText(words[1].length);
  event.args[1] = words.join(' ');
  sendEvent(event);
};

getHiddenPasswordText = function(length) {
  hiddenPasswordText = '';
  for (var i = 0; i < length; i++) {
    hiddenPasswordText += '*';
  }
  return hiddenPasswordText;
};

updatePasswords = function(loadedPasswords) {
  for (server in loadedPasswords) {
    if (!serverPasswords[server]) {
      serverPasswords[server] = loadedPasswords[server];
    }
  }
};
