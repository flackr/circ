setName('znc_replay');
setDescription('suspends notifications on znc buffer playback');

send('hook_message', 'privmsg');

var playbackCount = 0;

this.onMessage = function(e) {
  if (e.type == 'message' && e.name == 'privmsg') {
    var source = e.args[0];
    var message = e.args[1];
    if (source == '***') {
      if (message == 'Playback Complete.') {
        playbackCount--;
        if (playbackCount == 0) {
          // send command to resume notifications.
          send(e.context, 'command', 'suspend-notifications', 'off');
        }
        propagate(e, 'none');
        return;
      }

      if (message == 'Buffer Playback...') {
        if (playbackCount == 0) {
          // send command to suspend notifications.
          send(e.context, 'command', 'suspend-notifications', 'on');
        }
        playbackCount++;
        propagate(e, 'none');
        return;
      }
    }
  }
  propagate(e);
};

