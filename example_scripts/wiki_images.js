setName('wiki_images');
setDescription('displays a wikimedia image when one is linked');

send('hook_message', 'privmsg');
onMessage = function(e) {
  propagate(e);
  imageRegex = /http:\/\/upload\.wikimedia\.org\/\S+/i;
  message = e.args[1];
  matches = message.match(imageRegex);
  if (matches) {
    send(e.context, 'command', 'image', matches[0]);
  }
};
