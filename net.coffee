exports = window.net = {}

# TCP socket.
# Events emitted:
# - 'connect': the connection succeeded, proceed.
# - 'data': data received. Argument is the data (array of longs, atm)
# - 'end': the other end sent a FIN packet, and won't accept any more data.
# - 'error': an error occurred. The socket is pretty much hosed now. (TODO:
#	  investigate how node deals with errors. The docs say 'close' gets sent right
#	  after 'error', so they probably destroy the socket.)
# - 'close': emitted when the socket is fully closed.
# TODO: 'drain': emitted when the write buffer becomes empty
class Socket
	constructor: ->
		@listeners = {}
	on: (ev, cb) ->
		(@listeners[ev] ?= []).push cb
	removeListener: (ev, cb) ->
		return unless @listeners and @listeners[ev] and cb?
		@listeners[ev] = (l for l in @listeners[ev] when l != cb and l.listener != cb)
	once: (ev, cb) ->
		@on ev, f = (args...) =>
			@removeListener ev, f
			cb(args...)
		f.listener = cb
	emit: (ev, args...) ->
		l(args...) for l in (@listeners[ev] ? [])

	connect: (port, host='localhost') ->
		@_active()
		go = (err, addr) =>
			return @emit 'error', "couldn't resolve: #{err}" if err
			@_active()
			options = onEvent: @_onEvent
			chrome.experimental.socket.create 'tcp', options, (si) =>
				@socketId = si.socketId
				if @socketId > 0
					chrome.experimental.socket.connect @socketId, addr, port, (rc) =>
						# useless; at this point the connect actually hasn't happened.
						# wait for connectComplete event.
				else
					return @emit 'error', "couldn't create socket"

		if /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$/.test host
			go null, host
		else
			Socket.resolve host, go


	write: (data) ->
		@_active()
		chrome.experimental.socket.write @socketId, data, (writeInfo) =>
			if writeInfo.bytesWritten < -1
				@emit 'error', writeInfo.bytesWritten
			if writeInfo.bytesWritten == data.length
				@emit 'drain' # TODO not sure if this works, don't rely on this message

	# looks to me like there's no equivalent to node's end() in the socket API
	destroy: ->
		chrome.experimental.socket.disconnect @socketId
		@emit 'close' # TODO: figure out whether i should emit 'end' as well?

	end: ->
		# TODO: only half-close the socket
		chrome.experimental.socket.disconnect @socketId
		@emit 'close'

	_onEvent: (ev) =>
		@_active()
		switch ev.type
			when 'connectComplete'
				if ev.resultCode < 0
					# TODO: I'm pretty sure we should never get a -1 here..
					# TODO: we should destroy the socket when we get an error.
					@emit 'error', ev.resultCode
				else
					@emit 'connect'
					chrome.experimental.socket.read @socketId, @_onRead

			when 'dataRead'
				@_onRead {data: ev.data, resultCode: ev.resultCode}

			when 'writeComplete'
				if ev.resultCode < 0
					console.error "SOCKET ERROR on write: ", ev.resultCode
				@emit 'drain' # TODO not sure if this is the right place to send this event

			else
				console.log "unknown socket event type: #{ev.type}", ev

	_onRead: (readInfo) =>
		console.log "onRead", readInfo
		@_active() unless readInfo.resultCode is -1
		if readInfo.resultCode < -1 # -1 is EWOULDBLOCK
			@emit 'error', readInfo.resultCode
		else if readInfo.resultCode is 0
			@emit 'end'
			@destroy() # TODO: half-open sockets
		if readInfo.data.length
			@emit 'data', readInfo.data

			chrome.experimental.socket.read @socketId, @_onRead

	_active: ->
		if @timeout
			clearTimeout @timeout
			@timeout = setTimeout (=> @emit 'timeout'), @timeout_ms

	setTimeout: (ms, cb) ->
		if ms > 0
			@timeout = setTimeout (=> @emit 'timeout'), ms
			@timeout_ms = ms
			@once 'timeout', cb if cb
		else if ms == 0
			clearTimeout @timeout
			@removeListener 'timeout', cb if cb
			@timeout = null
			@timeout_ms = 0

	@resolve: (host, cb) ->
		chrome.experimental.dns.resolve host, (res) ->
			if res.resultCode is 0
				cb(null, res.address)
			else
				cb(res.resultCode)

exports.Socket = Socket
