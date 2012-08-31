exports = window.irc ?= {}

class IRC extends EventEmitter
  constructor: (@server, @port, @opts={}) ->
    super
    @opts.nick ?= "irc5-#{@util.randomName()}"

    @partialNameLists = {}
    @channels = {}
    @serverMessageHandler = new irc.ServerMessageHandler(this)
    @util = irc.util
    @state = 'disconnected'

    @socket = new net.Socket
    @socket.on 'connect', => @onConnect()
    @socket.on 'data', (data) => @onData data
    @socket.on 'drain', => @onDrain()
    # TODO: differentiate these events. /quit is not same as sock err
    @socket.on 'error', (err) => @onError err
    @socket.on 'end', (err) => @onEnd err
    @socket.on 'close', (err) => @onClose err
    @data = @util.emptySocketData()

  # user-facing
  connect: ->
    assert @state in ['disconnected', 'reconnecting']
    clearTimeout @reconnect_timer if @reconnect_timer
    @reconnect_timer = null
    @socket.connect(@port, @server)
    @state = 'connecting'

  # user-facing
  quit: (reason) ->
    assert @state is 'connected'
    @send 'QUIT', reason
    @state = 'disconnected'
    @endSocketOnDrain = true

  # user-facing
  giveup: ->
    assert @state is 'reconnecting'
    clearTimeout @reconnect_timer
    @reconnect_timer = null
    @state = 'disconnected'

  # user-facing
  doCommand: (cmd, args...) ->
    @sendIfConnected(cmd, args...)

  onConnect: ->
    @send 'PASS', @opts.password if @opts.password
    @send 'NICK', @opts.nick
    @send 'USER', @opts.nick, '0', '*', 'An irc5 user'
    @socket.setTimeout 60000, @onTimeout

  onTimeout: =>
    @send 'PING', +new Date
    @socket.setTimeout 60000, @onTimeout

  onError: (err) ->
    console.error "socket error", err
    @setReconnect()
    @socket.end()

  onClose: ->
    @socket.setTimeout 0, @onTimeout
    @emit 'disconnect'
    if @state is 'connected'
      @setReconnect()

  onEnd: ->
    console.error "remote peer closed connection"
    if @state is 'connected'
      @setReconnect()

  setReconnect: ->
    @state = 'reconnecting'
    # TODO: exponential backoff
    @reconnect_timer = setTimeout @reconnect, 10000

  reconnect: =>
    @connect()

  onData: (pdata) ->
    @data = @util.concatSocketData @data, pdata
    dataView = new Uint8Array @data
    while dataView.length > 0
      cr = false
      crlf = undefined
      for d,i in dataView
        if d == 0x0d
          cr = true
        else if cr and d == 0x0a
          crlf = i
          break
        else
          cr = false
      if crlf?
        line = @data.slice(0, crlf-1)
        @data = @data.slice(crlf+1)
        dataView = new Uint8Array @data
        @util.fromSocketData line, (lineStr) =>
          console.log '<=', "(#{@server})", lineStr
          @onCommand(@util.parseCommand lineStr)
      else
        break

  onDrain: ->
    @socket.end() if @endSocketOnDrain

  send: (args...) ->
    msg = @util.makeCommand args...
    console.log('=>', "(#{@server})", msg[0...msg.length-2])
    @util.toSocketData msg, (arr) => @socket.write arr

  sendIfConnected: (args...) ->
    @send args... if @state is 'connected'

  onCommand: (cmd) ->
    cmd.command = parseInt(cmd.command, 10) if /^\d{3}$/.test cmd.command
    if @serverMessageHandler.canHandle cmd.command
      @serverMessageHandler.handle cmd.command, @util.parsePrefix(cmd.prefix),
        cmd.params...
    else
      console.log 'Unknown cmd:', cmd.command
      @emit 'message', undefined, 'unknown', cmd

exports.IRC = IRC
