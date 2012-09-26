exports = window.chat ?= {}

class MockChat
  constructor: (irc) ->
    irc.on 'server', (e) =>
      switch e.name
        when 'connect' then @onConnected()
        when 'disconnect' then @onDisconnected()
        when 'joined' then @onJoined e.context.channel, e.args...
        when 'names' then @onNames e.context.channel, e.args...
        when 'parted' then @onParted e.context.channel, e.args...
    irc.on 'message', (e) => @onIRCMessage e.context.channel, e.name, e.args...

  onConnected: ->
  onDisconnected: ->
  onIRCMessage: ->
  onJoined: ->
  onParted: ->

exports.MockChat = MockChat