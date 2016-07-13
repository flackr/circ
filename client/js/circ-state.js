window.exports = window.exports || {};

exports.CircState = function() {

  function CircState(state) {
    this.state = state;
  }

  CircState.prototype = {
    // Override these functions to be notified about various events.
    onjoin: function(channel) {},

    process: function(message) {
      var words = message.split(' ', 3);
      // TODO(flackr): Check user who has joined.
      if (words[1] == "JOIN")
        this.state[words[2].substring(1)] = {};
      // TODO(flackr): Check for part.
    },
  }

  return CircState;
}();