if (typeof window !== 'undefined')
  window.exports = window.exports || {};

exports.CircState = function() {

  function getUser(userPart) {
    var source = userPart.split('!');
    if (source.length == 1)
      return '';
    return source[0].substring(1);
  }

  function CircState(state/* = {}*/) {
    state['channels'] = state['channels'] || {}
    this.state = state;
  }

  CircState.prototype = {
    // Override these functions to be notified about various events.
    onjoin: function(channel) {},
    onpart: function(channel) {},
    onnick: function(oldNick, newNick) {},
    onownnick: function(nick) {},
    onmessage: function(from, to, message) {},

    process: function(message) {
      var words = message.split(' ', 3);
      var user = getUser(words[0]);
      // TODO(flackr): Check user who has joined.
      if (words[1] == "JOIN" && user == this.state.nick) {
        var channel = words[2].substring(1);
        this.state.channels[channel] = {};
        this.onjoin(channel);
      } else if (words[1] == "PART") {
        var channel = words[2].substring(1);
        if (user == this.state.nick) {
          delete this.state.channels[channel];
          this.onpart(channel);
        }
      } else if (words[1] == "NICK") {
        var newNick = words[2].substring(1)
        if (user == this.state.nick) {
          this.state.nick = newNick;
          this.onownnick(newNick);
        }
        this.onnick(user, newNick);
      } else if (words[1] == "PRIVMSG") {
        var message = message.substring(words[0].length + words[2].length + 11);
        this.onmessage(getUser(words[0]), words[2], message);
      }
    },

    processOutbound: function(message) {
      var words = message.split(' ', 2);
      if (words[0] == 'PRIVMSG') {
        var rest = message.substring(words[0].length + words[1].length + 3);
        this.onmessage(this.state.nick, words[1], rest);
      }
    },
  }

  return CircState;
}();