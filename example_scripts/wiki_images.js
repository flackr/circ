setName('wiki_images');
setDescription('displays a wikimedia image when one is linked');

send('hook_message', 'privmsg');
this.onMessage = function(e) {
  propagate(e);
  var imageRegex = /http:\/\/upload\.wikimedia\.org\/\S+/i;
  var message = e.args[1];
  var matches = message.match(imageRegex);
  if (matches) {
    send(e.context, 'command', 'image', matches[0]);
  }
};
