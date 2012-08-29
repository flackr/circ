connect = ->
	host = document.getElementById('host').value
	c = new irc.IRC host, 6667
	c.connect()
	return
	chrome.experimental.socket.create 'tcp', '127.0.0.1', 8080, (socketInfo) ->
		id = socketInfo.socketId
		console.log id
		chrome.experimental.socket.connect id, (result) ->
			console.log result
			chrome.experimental.socket.write id, "Hello, world!", (sendInfo) ->
				console.log sendInfo

document.getElementById('connect').onclick = connect
