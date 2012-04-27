escapeHTML = (html) ->
	escaped = {
		'&': '&amp;',
		'<': '&lt;',
		'>': '&gt;',
		'"': '&quot;',
	}
	String(html).replace(/[&<>"]/g, (chr) -> escaped[chr])

display = (text) ->
	# Gruber's url-finding regex
	rurl = /\b((?:[a-z][\w-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,  ↪ 4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*   ↪ \)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))/gi
	canonicalise = (url) ->
		url = escapeHTML url
		if url.match(/^[a-z][\w-]+:/i)
			url
		else
			'http://' + url

	escape = (str) ->
		escapeHTML(str).replace(/\S{40,}/,'<span class="longword">$&</span>')
	res = ''
	textIndex = 0
	while m = rurl.exec text
		res += escape(text.substr(textIndex, m.index - textIndex))
		res += '<a target="_blank" href="'+canonicalise(m[0])+'">'+escape(m[0])+'</a>'
		textIndex = m.index + m[0].length
	res += escape(text.substr(textIndex))
	return res


parsePrefix = (prefix) ->
	p = /^([^!]+?)(?:!(.+?)(?:@(.+?))?)?$/.exec(prefix)
	{ nick: p[1], user: p[2], host: p[3] }

class IRC5
	constructor: ->
		@status '(connecting...)'

		@irc = new irc.IRC # TODO hrm

		@$main = $('#main')
		@nick = undefined

		@systemWindow = new Window('system')
		@switchToWindow @systemWindow
		@windows = {}
		@winList = [@systemWindow]

		@partialNameLists = {}

	onConnected: => @status 'connected'
	onDisconnected: => @status 'disconnected'

	disconnect: ->
		@irc.quit 'App closing.'

	onMessage: (msg) =>
		prefix = parsePrefix msg.prefix
		cmd = if /^\d{3}$/.test(msg.command)
			parseInt(msg.command)
		else
			msg.command
		if handlers[cmd]
			handlers[cmd].apply(this, [prefix].concat(msg.params))
		else
			@systemWindow.message prefix.nick, msg.command + ' ' + msg.params.join(' ')

	handlers = {
		# RPL_WELCOME
		1: (from, target, msg) ->
			# once we get a welcome message, we know who we are
			@nick = target
			@status()
			@systemWindow.message from.nick, msg

		# RPL_NAMREPLY
		353: (from, target, privacy, channel, names) ->
			names = names.split(/\x20/)
			@partialNameLists[channel] ||= []
			@partialNameLists[channel] = @partialNameLists[channel].concat(names)

		366: (from, target, channel, _) ->
			if @windows[channel]
				@windows[channel].names = @partialNameLists[channel]
			delete @partialNameLists[channel]

		NICK: (from, newNick, msg) ->
			if from.nick == @nick
				@nick = newNick
				@status()
			for chan,win of @windows when from.nick in win.names
				win.names[win.names.indexOf from.nick] = newNick

		JOIN: (from, chan) ->
			if from.nick == @nick
				win = new Window(chan)
				win.target = chan
				@windows[win.target] = win
				@winList.push(win)
				@switchToWindow win
			if win = @windows[chan]
				win.message('', "#{from.nick} joined the channel.")
				win.names.push(from.nick) if win.names

		PART: (from, chan) ->
			if win = @windows[chan]
				win.message('', "#{from.nick} left the channel.")
				win.names = win.names.filter (n) -> n != from.nick # ugh, hack :/

		QUIT: (from, reason) ->
			for chan, win of @windows when from.nick in win.names
				win.names = win.names.filter (n) -> n != from.nick # ugh, hack :/
				win.message('', "#{from.nick} quit: #{reason}")

		PRIVMSG: (from, target, msg) ->
			win = @windows[target] || @systemWindow
			if m = /^\u0001ACTION (.*)\u0001/.exec msg
				win.message '', "#{from.nick} #{m[1]}", type:'privmsg action'
			else
				win.message from.nick, msg, type:'privmsg'

		PING: -> # server handles these for us.
		# TODO: maybe don't even forward pings to client?
	}

	send: (msg...) ->
		@irc.send msg...

	status: (status) ->
		if !status
			status = "[#{@nick}] #{@currentWindow.target}"
		$('#status').text(status)

	switchToWindow: (win) ->
		if @currentWindow
			@currentWindow.scroll = @currentWindow.$container.scrollTop()
			@currentWindow.wasScrolledDown = @currentWindow.isScrolledDown()
			@currentWindow.$container.detach()
		@$main.append win.$container
		if win.wasScrolledDown
			win.scroll = win.$container[0].scrollHeight
		win.$container.scrollTop(win.scroll)
		@currentWindow = win
		@status()

	commands = {
		join: (chan) ->
			@send 'JOIN', chan
		win: (num) ->
			num = parseInt(num)
			@switchToWindow @winList[num] if num < @winList.length
		say: (text...) ->
			if target = @currentWindow.target
				msg = text.join(' ')
				@onMessage prefix: @nick, command: 'PRIVMSG', params: [target, msg]
				@send 'PRIVMSG', target, msg
		me: (text...) ->
			commands.say.call(this, '\u0001ACTION '+text.join(' ')+'\u0001')
		nick: (newNick) ->
			@irc.opts.nick = newNick
			@send 'NICK', newNick
		connect: (server, port) ->
			@switchToWindow @systemWindow
			@windows = {}
			@winList = [@systemWindow]
			@irc = new irc.IRC server, parseInt(port ? 6667)
			@irc.on 'connect', => @onConnected()
			@irc.on 'disconnect', => @onDisconnected()
			@irc.on 'message', (cmd) => @onMessage cmd
			@irc.connect()
		names: ->
			if names = @currentWindow.names
				@currentWindow.message('', JSON.stringify names.slice().sort())
	}

	command: (text) ->
		if text[0] == '/'
			cmd = text[1..].split(/\s+/)
			if func = commands[cmd[0].toLowerCase()]
				func.apply(this, cmd[1..])
			else
				console.log "no such command"
		else
			commands.say.call(this, text)


class Window
	constructor: (@name) ->
		@$container = $ "<div id='chat-container'>"
		@$messages = $ "<div id='chat'>"
		@$container.append @$messages

	isScrolledDown: ->
		scrollBottom = @$container.scrollTop() + @$container.height()
		scrollBottom == @$container[0].scrollHeight

	message: (from, msg, opts={}) ->
		scroll = @isScrolledDown
		e = escapeHTML
		extra_classes = [opts.type]
		msg = display msg
		@$messages.append $("""
		<div class='message #{extra_classes.join(' ')}'>
			<div class='source'>#{e from}</div>
			<div class='text'>#{msg}</div>
		</div>
		""")
		if scroll
			@$container.scrollTop(@$container[0].scrollHeight)

irc5 = new IRC5

$cmd = $('#cmd')
$cmd.focus()
$(window).keydown (e) ->
	unless e.metaKey or e.ctrlKey
		e.currentTarget = $('#cmd')[0]
		$cmd.focus()
	if e.altKey and 48 <= e.which <= 57
		irc5.command("/win " + (e.which - 48))
		e.preventDefault()
$cmd.keydown (e) ->
	if e.which == 13
		cmd = $cmd.val()
		if cmd.length > 0
			$cmd.val('')
			irc5.command cmd

window.onbeforeunload = ->
	irc5.disconnect()
