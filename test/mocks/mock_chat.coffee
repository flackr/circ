exports = window.chat ?= {}

class MockChat
  constructor: (irc) ->
    irc.on 'connect', => @onConnected()
    irc.on 'disconnect', => @onDisconnected()
    irc.on 'message', (target, type, args...) =>
      @onIRCMessage target, type, args...
    irc.on 'joined', (chan) => @onJoined chan
    irc.on 'parted', (chan) => @onJoined chan

  onConnected: () ->
  onDisconnected: () ->
  onIRCMessage: (target, type, args...) ->
  onJoined: (chan) ->
  onParted: (chan) ->

exports.MockChat = MockChat