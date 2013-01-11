exports = window.irc ?= {}

##
# Represents a connection to an IRC server.
##
class IRC extends EventEmitter
  constructor: (opt_socket) ->
    super
    @util = irc.util
    @preferredNick = "circ-user-#{@util.randomName(5)}"
    @setSocket opt_socket ? new net.ChromeSocket
    @data = @util.emptySocketData()

    @exponentialBackoff = 0
    @partialNameLists = {}
    @channels = {}
    @serverResponseHandler = new irc.ServerResponseHandler this
    @state = 'disconnected'

  setSocket: (socket) ->
    delete @socket
    @socket = socket
    @socket.on 'connect', => @onConnect()
    @socket.on 'data', (data) => @onData data
    @socket.on 'drain', => @onDrain()
    @socket.on 'error', (err) => @onError err
    @socket.on 'end', (err) => @onEnd err
    @socket.on 'close', (err) => @onClose err

  setPreferredNick: (@preferredNick) ->

  # user-facing
  connect: (@server=@server, @port=@port, @password=@password) ->
    return if @state not in ['disconnected', 'reconnecting']
    clearTimeout @reconnectTimeout
    @socket.connect(@server, @port)
    @state = 'connecting'

  # user-facing
  quit: (reason) ->
    if @state in ['connected', 'disconnecting']
      @send 'QUIT', reason ? @quitReason
      @state = 'disconnected'
      @endSocketOnDrain = true
    else
      @quitReason = reason
      @state = 'disconnecting'

  # user-facing
  giveup: ->
    return unless @state is 'reconnecting'
    clearTimeout @reconnectTimeout
    @state = 'disconnected'

  join: (channel) ->
    if @state is 'connected'
      @doCommand 'JOIN', channel
    else if not @channels[channel]
      @channels[channel] = {names:[]}

  part: (channel, reason) ->
    if @state is 'connected'
      @doCommand 'PART', channel, reason
    else if @channels[channel]
      delete @channels[channel]

  # user-facing
  doCommand: (cmd, args...) ->
    @sendIfConnected(cmd, args...)

  onConnect: ->
    @send 'PASS', @password if @password
    @send 'NICK', @preferredNick
    @send 'USER', @preferredNick, '0', '*', 'A CIRC user'
    @socket.setTimeout 60000, @onTimeout

  onTimeout: =>
    @send 'PING', +new Date
    @socket.setTimeout 60000, @onTimeout

  onError: (err) ->
    @emitMessage 'socket_error', chat.SERVER_WINDOW, err
    @setReconnect()
    @socket.close()

  onClose: ->
    @socket.setTimeout 0, @onTimeout
    if @state is 'connected'
      @emit 'disconnect'
      @setReconnect()

  onEnd: ->
    console.error "remote peer closed connection"
    if @state is 'connected'
      @setReconnect()

  setReconnect: ->
    @state = 'reconnecting'
    backoff = 2000 * Math.pow 2, @exponentialBackoff
    @reconnectTimeout = setTimeout @reconnect, backoff
    @exponentialBackoff++ unless @exponentialBackoff > 4

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
          @onServerMessage(@util.parseCommand(lineStr))
      else
        break

  onDrain: ->
    @socket.close() if @endSocketOnDrain
    @endSocketOnDrain = false

  send: (args...) ->
    msg = @util.makeCommand args...
    console.log('=>', "(#{@server})", msg[0...msg.length-2])
    @util.toSocketData msg, (arr) => @socket.write arr

  sendIfConnected: (args...) ->
    @send args... if @state is 'connected'

  onServerMessage: (cmd) ->
    cmd.command = parseInt(cmd.command, 10) if /^\d{3}$/.test cmd.command
    if @serverResponseHandler.canHandle cmd.command
      @handle cmd.command, @util.parsePrefix(cmd.prefix), cmd.params...
    else
      @emitMessage 'other', chat.SERVER_WINDOW, cmd

  handle: (cmd, args...) ->
    @serverResponseHandler.handle cmd, args...

  emit: (name, channel, args...) ->
    event = new Event 'server', name, args...
    event.setContext @server, channel
    @emitCustomEvent event

  emitMessage: (name, channel, args...) ->
    event = new Event 'message', name, args...
    event.setContext @server, channel
    @emitCustomMessage event

  emitCustomMessage: (event) ->
    @emitCustomEvent event

  emitCustomEvent: (event) ->
    IRC.__super__.emit.call(this, event.type, event)

  isOwnNick: (nick) ->
    irc.util.nicksEqual @nick, nick

# Our IRC version - should match the version in the manifest.
exports.VERSION = "0.5.7"

exports.IRC = IRC
