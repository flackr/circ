if (typeof window !== 'undefined')
  window.exports = window.exports || {};

exports.CircState = function() {

  function getUser(userPart) {
    var source = userPart.split('!');
    if (source.length == 1)
      return '';
    return source[0].substring(1);
  }

  function CircState(state) {
    state['channels'] = state['channels'] || {}
    state['events'] = state['events'] || []
    this.state = state;
  }

  CircState.prototype = {
    // Override these functions to be notified about various events.
    onjoin: function(channel) {},
    onpart: function(channel) {},
    onnick: function(oldNick, newNick) {},
    onownnick: function(nick) {},
    onevent: function(channel, event) {},

    process: function(message, timestamp) {
      var words = message.split(' ', 3);
      var user = getUser(words[0]);
      // TODO(flackr): Check user who has joined.
      if (words[1] == "JOIN") {
        if (user == this.state.nick) {
          var channel = words[2].substring(1);
          this.state.channels[channel] = {'events': [], 'topic': '', 'users': []};
          this.onjoin(channel);
        }
        this.processEvent_(channel, {
          'time': timestamp,
          'type': 'JOIN',
          'from': user,
          'data': message,
        });
      } else if (words[1] == "PART") {
        var channel = words[2].substring(1);
        if (user == this.state.nick) {
          delete this.state.channels[channel];
          this.onpart(channel);
        } else {
          this.processEvent_(channel, {
            'time': timestamp,
            'type': 'PART',
            'from': user,
            'data': message,
          });
        }
      } else if (words[1] == "NICK") {
        var newNick = words[2].substring(1)
        if (user == this.state.nick) {
          this.state.nick = newNick;
          this.onownnick(newNick);
        }
        this.onnick(user, newNick);
        this.processEvent_('', {
          'time': timestamp,
          'type': 'NICK',
          'from': user,
          'data': message,
        });
      } else if (words[1] == "PRIVMSG") {
        var message = message.substring(words[0].length + words[2].length + 11);
        var from = getUser(words[0]);
        var targetChannel = words[2] == this.state.nick ? from : words[2];
        this.processEvent_(targetChannel, {
          'time': timestamp,
          'type': 'PRIVMSG',
          'from': from,
          'data': message,
        });
      }
    },

    processOutbound: function(message, timestamp) {
      var words = message.split(' ', 2);
      if (words[0] == 'PRIVMSG') {
        var rest = message.substring(words[0].length + words[1].length + 2);
        this.processEvent_(words[1], {
          'time': timestamp,
          'type': 'PRIVMSG',
          'from': this.state.nick,
          'data': rest,
        });
      }
    },
    
    processEvent_: function(channel, event) {
      if (channel) {
        if (!this.state.channels[channel])
          this.state.channels[channel] = {'events': []};
        this.state.channels[channel].events.push(event);
      } else {
        this.state.events.push(event);
      }
      this.onevent(channel, event);
    },
  }

  return CircState;
}();