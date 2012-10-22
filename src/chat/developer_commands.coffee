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
      @_handleCommand "load", ""

    z: ->
      @_handleCommand 'add-device', '172.23.181.94'

    z2: ->
      @_handleCommand 'make-server', ''

    z3: ->
      @_handleCommand 'close-sockets', ''

    a: (addr='127.0.0.1', port='1341') ->
      port = parseInt port
      chrome.socket.create 'tcp', {}, (socketInfo) =>
        @socketId2 = socketInfo.socketId
        console.warn 'created socket 2', @socketId2

        chrome.socket.listen @socketId2, addr, port, (rc) =>
          console.warn 'socket 2 is now listening on', addr, port, '- RC:', rc

          chrome.socket.accept @socketId2, (acceptInfo) =>
            console.warn 'socket 2 accepted a connection!',
                acceptInfo.resultCode, acceptInfo.socketId
            @socketId3 = acceptInfo.socketId
            console.warn 'socket 3 created!', @socketId3
            chrome.socket.read @socketId3, (ri) => @_onRead @socketId3, ri

    b: (addr='127.0.0.1', port='1341') ->
      port = parseInt port
      chrome.socket.create 'tcp', {}, (socketInfo) =>
        @socketId = socketInfo.socketId
        console.warn 'created socket 1', @socketId
        chrome.socket.connect @socketId, addr, port, @_onConnect

    c: (s, msg) ->
      id = if s is 1 then @socketId else if s is 2 then @socketId2 else @socketId3
      console.warn 'about to send', msg
      irc.util.toSocketData msg, (data) =>

        chrome.socket.write id, data, (writeInfo) =>
          if writeInfo.resultCode < 0
            console.error s, "writeData: error on write: ", writeInfo.resultCode
          if writeInfo.bytesWritten == data.byteLength
            console.warn s, 'drain'
          else
            console.error s, "Waaah can't handle non-complete writes"

    d: ->
      try
        chrome.socket.destroy @socketId
      catch error
        console.error "couldn't close socket 1", error
      try
        chrome.socket.destroy @socketId2
      catch error
        console.error "couldn't close socket 2", error
      try
        chrome.socket.destroy @socketId3
      catch error
        console.error "couldn't close socket 3", error

    e: ->
      chrome.socket.getNetworkList (nis) =>
        for ni, i in nis
          console.warn 'network interface', i + ':', ni.name, ni.address

    f: ->
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

  _handleCommand: (command, text) ->
    event = { context:
      server: @_chat.currentWindow.conn?.name
      chan: @_chat.currentWindow.target }
    @_chat.userCommands.handle command, event, text.split(' ')...

exports.DeveloperCommands = DeveloperCommands