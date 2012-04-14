exports = window.net = {}

class Socket
	constructor: ->
		@listeners = {}
	on: (ev, cb) ->
		(@listeners[ev] ?= []).push cb
	emit: (ev, args...) ->
		l(args...) for l in (@listeners[ev] ? [])

	connect: (port, host='localhost') ->
		Socket.resolve host, (err, addr) =>
			throw new Error("couldn't resolve: " + err) if err
			console.log "Resolved #{host} to #{addr}"
			options = onEvent: @_onEvent
			chrome.experimental.socket.create 'tcp', addr, port, options, (si) =>
				@socketId = si.socketId
				if @socketId > 0
					chrome.experimental.socket.connect @socketId, (rc) =>
						# useless; at this point the connect actually hasn't happened.
						# wait for connectComplete event.
						console.log "connect callback", rc
				else
					throw new Error "couldn't create socket"

	write: (data) ->
		chrome.experimental.socket.write @socketId, data, (writeInfo) =>
			if writeInfo.bytesWritten == data.length
				@emit 'drain' # TODO not sure if this works

	end: ->
		chrome.experimental.socket.disconnect @socketId

	_onEvent: (ev) =>
		switch ev.type
			when 'connectComplete'
				@emit 'connect'
				chrome.experimental.socket.read @socketId, @_onRead

			when 'dataRead'
				@_onRead {message: ev.data}

			when 'writeComplete'
				@emit 'drain' # TODO not sure if this works

			else
				console.log "unknown socket event type: #{ev.type}", ev

	_onRead: (readInfo) =>
		if readInfo.message
			@emit 'data', readInfo.message

			chrome.experimental.socket.read @socketId, @_onRead

	@resolve: (host, cb) ->
		chrome.experimental.dns.resolve host, (res) ->
			if res.resultCode is 0
				cb(null, res.address)
			else
				cb(res.resultCode)

exports.Socket = Socket
