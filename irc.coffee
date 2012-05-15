unless exports?
	exports = window.irc = {}

parseCommand = (data) ->
	str = data.toString('utf8')
	parts = ///
		^
		(?: : ([^\x20]+?) \x20)?        # prefix
		([^\x20]+?)                     # command
		((?:\x20 [^\x20:] [^\x20]*)+)?  # params
		(?:\x20:(.*))?                  # trail
		$
	///.exec(str)
	throw new Error("invalid IRC message: #{data}") unless parts
	# could do more validation here...
	# prefix = servername | nickname((!user)?@host)?
	# command = letter+ | digit{3}
	# params has weird stuff going on when there are 14 arguments

	# trim whitespace
	if parts[3]?
		parts[3] = parts[3].slice(1).split(/\x20/)
	else
		parts[3] = []
	parts[3].push(parts[4]) if parts[4]?
	{
		prefix: parts[1]
		command: parts[2]
		params: parts[3]
	}

parsePrefix = (prefix) ->
	p = /^([^!]+?)(?:!(.+?)(?:@(.+?))?)?$/.exec(prefix)
	{ nick: p[1], user: p[2], host: p[3] }

exports.parseCommand = parseCommand

makeCommand = (cmd, params...) ->
	_params = if params and params.length > 0
		if !params[0...params.length-1].every((a) -> !/^:|\x20/.test(a))
			throw new Error("some non-final arguments had spaces or initial colons in them")
		if /^:|\x20/.test(params[params.length-1])
			params[params.length-1] = ':'+params[params.length-1]
		' ' + params.join(' ')
	else
		''
	cmd + _params + "\x0d\x0a"

randomName = (length = 10) ->
	chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	(chars[Math.floor(Math.random() * chars.length)] for x in [0...length]).join('')

normaliseNick = (nick) ->
	nick.toLowerCase().replace(/[\[\]\\]/g, (x) -> ('[':'{', ']':'}', '|':'\\')[x])

nicksEqual = (a, b) -> normaliseNick(a) == normaliseNick(b)

# Many thanks to Dennis for his StackOverflow answer: http://goo.gl/UDanx
string2ArrayBuffer = (string, callback) ->
	bb = new WebKitBlobBuilder()
	bb.append(string)
	f = new FileReader()
	f.onload = (e) ->
		callback(e.target.result)
	f.readAsArrayBuffer(bb.getBlob())

arrayBuffer2String = (buf, callback) ->
	bb = new WebKitBlobBuilder()
	bb.append(buf)
	f = new FileReader()
	f.onload = (e) ->
		callback(e.target.result)
	f.readAsText(bb.getBlob())

toSocketData = (str, cb) ->
	string2ArrayBuffer str, (ab) ->
		cb ab

fromSocketData = (ab, cb) ->
	console.log ab
	arrayBuffer2String ab, cb

emptySocketData = -> new ArrayBuffer(0)
concatSocketData = (a, b) ->
  result = new ArrayBuffer a.byteLength + b.byteLength
  resultView = new Uint8Array result
  resultView.set new Uint8Array a
  resultView.set new Uint8Array(b), a.byteLength
  result

class EventEmitter
	on: (ev, cb) ->
		@_listeners ?= {}
		(@_listeners[ev] ?= []).push cb
	emit: (ev, args...) ->
		@_listeners ?= {}
		l(args...) for l in (@_listeners[ev] ? [])

assert = (cond) ->
	throw new Error("assertion failed") unless cond

class IRC extends EventEmitter
	constructor: (@server, @port, @opts) ->
		@opts ?= {}
		@opts.nick ?= "irc5-#{randomName()}"
		@socket = new net.Socket
		@socket.on 'connect', => @onConnect()
		@socket.on 'data', (data) => @onData data

		# TODO: differentiate these events. /quit is not same as sock err
		@socket.on 'error', (err) => @onError err
		@socket.on 'end', (err) => @onEnd err
		@socket.on 'close', (err) => @onClose err
		@data = emptySocketData()

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
		@data = concatSocketData @data, pdata
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
				fromSocketData line, (lineStr) =>
					console.log '<=', lineStr
					@onCommand(parseCommand lineStr)
			else
				break

	_send: (args...) ->
		msg = makeCommand args...
		console.log('=>', msg[0...msg.length-2])
		toSocketData msg, (arr) => @socket.write arr
	send: (args...) ->
		return unless @state is 'connected' # TODO hm
		@_send args...

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
				l[normaliseNick n] = n

		366: (from, target, channel, _) ->
			if @channels[channel]
				@channels[channel].names = @partialNameLists[channel]
			else
				console.warn "Got name list for #{channel}, but we're not in it?"
			delete @partialNameLists[channel]

		NICK: (from, newNick, msg) ->
			if nicksEqual from.nick, @nick
				@nick = newNick
			norm_nick = normaliseNick from.nick
			new_norm_nick = normaliseNick newNick
			for name,chan of @channels when norm_nick of chan.names
				delete chan.names[norm_nick]
				chan.names[new_norm_nick] = newNick
				@emit 'message', chan, 'nick', from.nick, newNick

# Channels persist from when the user types /join to when they type /part.

		JOIN: (from, chan) ->
			if nicksEqual from.nick, @nick
				if c = @channels[chan]
					c.names = []
				else
					@channels[chan] = {names:[]}
				@emit 'joined', chan
			if c = @channels[chan]
				c.names[normaliseNick from.nick] = from.nick
				@emit 'message', chan, 'join', from.nick
			else
				console.warn "Got JOIN for channel we're not in (#{channel})"

		PART: (from, chan) ->
			# TODO: when do we receive PART? can the server just PART us?
			if c = @channels[chan]
				delete c.names[normaliseNick from.nick]
				@emit 'message', chan, 'part', from.nick
			else
				console.warn "Got PART for channel we're not in (#{channel})"

			if nicksEqual from.nick, @nick
				@channels[chan]?.names = []
				@emit 'parted', chan


		QUIT: (from, reason) ->
			norm_nick = normaliseNick from.nick
			for name, c of @channels when norm_nick of c.names
				delete c.names[norm_nick]
				@emit 'message', chan, 'quit', from.nick

		PRIVMSG: (from, target, msg) ->
			# TODO: normalise channel target names
			# TODO: should we pass more info about from?
			@emit 'message', target, 'privmsg', from.nick, msg

		PING: (from, payload) ->
			@send 'PONG', payload

		PONG: (from, payload) -> # ignore for now. later, lag calc.

		# ERR_NICKNAMEINUSE
		433: (from, nick, msg) ->
			@opts.nick += '_'
			@emit 'message', undefined, 'nickinuse', nick, @opts.nick, msg
			@_send 'NICK', @opts.nick

	onCommand: (cmd) ->
		cmd.command = parseInt(cmd.command, 10) if /^\d{3}$/.test cmd.command
		if handlers[cmd.command]
			handlers[cmd.command].apply this,
				[parsePrefix cmd.prefix].concat cmd.params
		else
			@emit 'message', undefined, 'unknown', cmd

exports.IRC = IRC
