setName('/dance');
setDescription('Type /dance have a Kirby dance');

send('hook_command', 'dance');

var dance = "(>'-')> <('-'<) ^(' - ')^ <('-'<) (>'-')>";
this.onMessage = function(e) {
  send(e.context, 'command', 'say', dance);
  propagate(e, 'none');
};
