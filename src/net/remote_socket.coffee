exports = window.net ?= {}

##
# A fake socket used when using another device's IRC connection.
##
class RemoteSocket extends net.AbstractTCPSocket

  setTimeout: ->
  _active: ->

exports.RemoteSocket = RemoteSocket