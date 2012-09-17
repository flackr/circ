exports = window.chat ?= {}

class MockChat
  constructor: (irc, name='freenode.net') ->
    conn = {irc:irc, name, windows:{}}
    irc.on 'server', (e) =>
      switch e.name
        when 'connect' then @onConnected conn
        when 'disconnect' then @onDisconnected conn
        when 'joined' then @onJoined conn, e.context.channel, e.args...
        when 'names' then @onNames conn, e.context.channel, e.args...
        when 'parted' then @onParted conn, e.context.channel, e.args...
    irc.on 'message', (e) => @onIRCMessage conn, e.context.channel, e.name, e.args...

  onConnected: ->
  onDisconnected: ->
  onIRCMessage: ->
  onJoined: ->
  onParted: ->

exports.MockChat = MockChat