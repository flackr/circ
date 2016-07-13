window.exports = window.exports || {};

exports.CircState = function() {

  function CircState(state = {}) {
    state['channels'] = state['channels'] || {}
    this.state = state;
  }

  CircState.prototype = {
    // Override these functions to be notified about various events.
    onjoin: function(channel) {},

    process: function(message) {
      var words = message.split(' ', 3);
      // TODO(flackr): Check user who has joined.
      if (words[1] == "JOIN")
        this.state['channels'][words[2].substring(1)] = {};
      // TODO(flackr): Check for part.
    },

    getUser_: function(message) {
      var source = message.split(' ', 1)[0].split('!');
      if (source.length == 1)
        return '';
      return source[0].substring(1);
    }
  }

  return CircState;
}();