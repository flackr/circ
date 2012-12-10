setName('xkcd_embed');
setDescription('displays the xkcd comic when linked in a message');

send('hook_message', 'privmsg');
onMessage = function(e) {
  propagate(e);
  imageRegex = /http:\/\/imgs\.xkcd\.com\/comics\/\S+/i;
  message = e.args[1];
  console.warn("SCRIPT:", message, imageRegex.test(message), e);
  matches = message.match(imageRegex);
  if (matches) {
    send(e.context, 'command', 'image', matches[0]);
  }
};
