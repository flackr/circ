exports = window.chat ?= {}

class DeveloperCommands extends MessageHandler
  constructor: (@_chat) ->
    super

  _handlers:
    1: ->
      @_handleCommand "server", "irc.corp.google.com"

    sn: ->
      @_handleCommand "nick", "sugarman#{Math.floor(Math.random() * 100)}"

    2: ->
      @_handleCommand "server", "irc.prod.google.com"

    3: ->
      @_handleCommand "join", "#sugarman"

    4: ->
      @_handleCommand "say", "hello thar #{irc.util.randomName()}!"

    5: ->
      @_handleCommand "join", "#sugarman2"

    6: ->
      @_handleCommand "server", "poop.irc.net"

    7: ->
      @_handleCommand "server", "irc.freenode.net"

    n: ->
      new chat.Notification('test', 'hi!').show()

    l: ->
      @_handleCommand "load"

    z: ->
      @_handleCommand 'connect-info'

    zp: ->
      @_chat.displayMessage 'notice', @params[0].context, 'Your password is: ' +
          @_chat.remoteConnection._password

    zps: (event) ->
      @_chat.syncStorage._store 'password', event.args[0]
      @_chat.setPassword event.args[0]

    zo: ->
      console.warn 'is online?', window.navigator.onLine

  _onConnect: (rc) =>
    if rc < 0
      console.error "1 couldn't connect to socket:", rc
    else
      console.warn '1 waiting onRead'
      chrome.socket.read @socketId, (ri) => @_onRead @socketId, ri

  _onRead: (id, readInfo) =>
    s = if id is @socketId then '1' else if id is @socketId2 then '2' else '3'
    if readInfo.resultCode < 0
      console.error s, 'onRead: bad read', readInfo.resultCode
    else if readInfo.resultCode is 0
      console.error s, 'onRead: got result code 0, should close now'
    else if readInfo.data.byteLength
      console.warn s, 'got data:', readInfo.data
      irc.util.fromSocketData readInfo.data, (str) ->
          console.warn s, 'got msg:', str
      chrome.socket.read id, (ri) => @_onRead id, ri
    else
      console.error 'onRead: got no data!'

  _handleCommand: (command, text='') ->
    @_chat.userCommands.handle command, @params[0], text.split(' ')...

exports.DeveloperCommands = DeveloperCommands