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
    onnames: function(channel) {},

    process: function(message, timestamp) {
      var words = message.split(' ', 5);
      var user = getUser(words[0]);
      // TODO(flackr): Check user who has joined.
      if (words[1] == "JOIN") {
        var channel = words[2];
        if (channel[0] == ':')
          channel = channel.substring(1);
        if (user == this.state.nick) {
          this.state.channels[channel] = {'events': [], 'topic': '', 'users': []};
          this.onjoin(channel);
        } else {
          this.state.channels[channel].users.push(user);
        }
        this.processEvent_(channel, {
          'time': timestamp,
          'type': 'JOIN',
          'from': user,
          'data': message,
        });
      } else if (words[1] == "PART") {
        var channel = words[2];
        if (channel[0] == ':')
          channel = channel.substring(1);
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
          var users = this.state.channels[channel].users;
          var index = users.indexOf(user);
          if (index != -1) users.splice(index, 1);
        }
      } else if (words[1] == "NICK") {
        var newNick = words[2].substring(1)
        if (user == this.state.nick) {
          this.state.nick = newNick;
          this.onownnick(newNick);
        }
        for (var channel in this.state.channels) {
          var users = this.state.channels[channel].users;
          var index = users.indexOf(user);
          if (index != -1) {
            // TODO(flackr): Generate a nick change event in these channels.
            users[index] = newNick;
          }
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
      } else if (!user && words[1] == '353') {
        var channel = words[4];
        if (this.state.channels[channel]) {
          var users = this.state.channels[channel].users;
          var usersList = message.split(' ').slice(5);
          usersList[0] = usersList[0].substring(1);
          for (var i = 0; i < usersList.length; i++) {
            users.push(usersList[i]);
          }
        }
      } else if (!user && words[1] == '366') {
        this.onnames(words[3]);
      }
    },

    processOutbound: function(message, timestamp) {
      var words = message.split(' ', 2);
      if (words[0] == 'PRIVMSG') {
        var rest = message.substring(words[0].length + words[1].length + 3);
        this.processEvent_(words[1], {
          'time': timestamp,
          'type': 'PRIVMSG',
          'from': this.state.nick,
          'data': rest,
        });
      } else if (words[0] == 'NAMES') {
        var channel = words[1];
        if (channel[0] == ':')
          channel = channel.substring(1);
        // Clear user list in anticipation of receiving a fresh list
        if (this.state.channels[channel])
          this.state.channels[channel].users = [];
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