exports = window.irc ?= {}

class IRC extends EventEmitter
  constructor: (@server, @port, @opts) ->
    super
    @util = window.irc.util
    @opts ?= {}
    @opts.nick ?= "irc5-#{@util.randomName()}"
    @socket = new net.Socket
    @socket.on 'connect', => @onConnect()
    @socket.on 'data', (data) => @onData data
    @socket.on 'drain', => @onDrain()

    # TODO: differentiate these events. /quit is not same as sock err
    @socket.on 'error', (err) => @onError err
    @socket.on 'end', (err) => @onEnd err
    @socket.on 'close', (err) => @onClose err
    @data = @util.emptySocketData()

    @partialNameLists = {}
    @channels = {}

    @state = 'disconnected'

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

  onConnect: ->
    @_send 'PASS', @opts.password if @opts.password
    @_send 'NICK', @opts.nick
    @_send 'USER', @opts.nick, '0', '*', 'An irc5 user'
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

  _send: (args...) ->
    msg = @util.makeCommand args...
    console.log('=>', "(#{@server})", msg[0...msg.length-2])
    @util.toSocketData msg, (arr) => @socket.write arr
  send: (args...) ->
    @_send args... if @state is 'connected'

  onCommand: (cmd) ->
    cmd.command = parseInt(cmd.command, 10) if /^\d{3}$/.test cmd.command
    if handlers[cmd.command]
      handlers[cmd.command].apply this,
        [@util.parsePrefix cmd.prefix].concat cmd.params
    else
      console.warn 'Unknown cmd:', cmd.command
      @emit 'message', undefined, 'unknown', cmd

  handlers =
    # RPL_WELCOME
    1: (from, target, msg) ->
      @nick = target
      @emit 'connect'
      @state = 'connected'
      @emit 'message', undefined, 'welcome', msg
      for name,c of @channels
        @send 'JOIN', name

    # RPL_NAMREPLY
    353: (from, target, privacy, channel, names) ->
      l = (@partialNameLists[channel] ||= {})
      for n in names.split(/\x20/)
        n = n.replace /^[@+]/, '' # TODO: read the prefixes and modes that they imply out of the 005 message
        l[@util.normaliseNick n] = n
    # RPL_ENDOFNAMES
    366: (from, target, channel, _) ->
      if @channels[channel]
        @channels[channel].names = @partialNameLists[channel]
      else
        console.warn "Got name list for #{channel}, but we're not in it?"
      delete @partialNameLists[channel]

    NICK: (from, newNick, msg) ->
      if @util.nicksEqual from.nick, @nick
        @nick = newNick
      norm_nick = @util.normaliseNick from.nick
      new_norm_nick = @util.normaliseNick newNick
      for name,chan of @channels when norm_nick of chan.names
        delete chan.names[norm_nick]
        chan.names[new_norm_nick] = newNick
        @emit 'message', chan, 'nick', from.nick, newNick

    JOIN: (from, chan) ->
      if @util.nicksEqual from.nick, @nick
        if c = @channels[chan]
          c.names = []
        else
          @channels[chan] = {names:[]}
        @emit 'joined', chan
      if c = @channels[chan]
        c.names[@util.normaliseNick from.nick] = from.nick
        @emit 'message', chan, 'join', from.nick
      else
        console.warn "Got JOIN for channel we're not in (#{channel})"

    PART: (from, chan) ->
      # TODO: when do we receive PART? can the server just PART us?
      if c = @channels[chan]
        delete c.names[@util.normaliseNick from.nick]
        @emit 'message', chan, 'part', from.nick
      else
        console.warn "Got PART for channel we're not in (#{channel})"

      if @util.nicksEqual from.nick, @nick
        @channels[chan]?.names = []
        @emit 'parted', chan

    QUIT: (from, reason) ->
      norm_nick = @util.normaliseNick from.nick
      for name, chan of @channels when norm_nick of chan.names
        delete chan.names[norm_nick]
        @emit 'message', chan, 'quit', from.nick

    PRIVMSG: (from, target, msg) ->
      # TODO: normalise channel target names
      # TODO: should we pass more info about from?
      @emit 'message', target, 'privmsg', from.nick, msg

    PING: (from, payload) ->
      @_send 'PONG', payload

    PONG: (from, payload) -> # ignore for now. later, lag calc.

    # ERR_NICKNAMEINUSE
    433: (from, nick, msg) ->
      @opts.nick += '_'
      @emit 'message', undefined, 'nickinuse', nick, @opts.nick, msg
      @_send 'NICK', @opts.nick

exports.IRC = IRC
