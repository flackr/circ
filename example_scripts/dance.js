onMessage = function(e) {
  dance = "(>'-')> <('-'<) ^(' - ')^ <('-'<) (>'-')>";
  send(e.context, 'command', 'say', dance);
  propagate(e, 'none');
};

send('hook_command', 'dance');