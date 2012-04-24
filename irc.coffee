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

arrayBufferToArrayOfLongs = (arrayBuffer) ->
  longs = []
  arrayBufferView = new Uint8Array(arrayBuffer)
  for i in [0...arrayBufferView.length]
    longs[i] = arrayBufferView[i]
  longs

arrayOfLongsToArrayBuffer = (longs) ->
	ab = new ArrayBuffer longs.length
	abView = new Uint8Array ab
	for i in [0...longs.length]
		abView[i] = longs[i]
	ab

toSocketData = (str, cb) ->
	string2ArrayBuffer str, (ab) ->
		cb arrayBufferToArrayOfLongs ab

fromSocketData = (arr, cb) ->
	ab = arrayOfLongsToArrayBuffer arr
	arrayBuffer2String ab, cb

class EventEmitter
	on: (ev, cb) ->
		@_listeners ?= {}
		(@_listeners[ev] ?= []).push cb
	emit: (ev, args...) ->
		@_listeners ?= {}
		l(args...) for l in (@_listeners[ev] ? [])

class IRC extends EventEmitter
	constructor: (@server, @port, @opts) ->
		@opts ||= {}
		@opts.nick ||= "irc5-#{randomName()}"
		@socket = new net.Socket
		@socket.on 'connect', => @onConnect()
		@socket.on 'data', (data) => @onData data
		@data = []

	connect: ->
		@socket.connect(@port, @server)

	quit: (reason) ->
		@send 'QUIT', reason
		@socket.end()
		@emit 'disconnect'

	onConnect: ->
		@emit 'connect'
		@send 'PASS', @opts.password if @opts.password
		@send 'NICK', @opts.nick
		@send 'USER', @opts.nick, '0', '*', 'An irc5 user'

	onData: (pdata) ->
		@data = @data.concat pdata
		while @data.length > 0
			cr = false
			crlf = undefined
			for d,i in @data
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
				fromSocketData line, (lineStr) =>
					console.log '<=', lineStr
					@onCommand(parseCommand lineStr)
			else
				break

	send: (args...) ->
		msg = makeCommand args...
		console.log('=>', msg[0...msg.length-2])
		toSocketData msg, (arr) => @socket.write arr

	onCommand: (cmd) ->
		switch cmd.command
			when 'PING'
				@send 'PONG', cmd.params
			when '433'
				@opts.nick += '_'
				@send 'NICK', @opts.nick

		@emit 'message', cmd

exports.IRC = IRC
