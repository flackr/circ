exports = window.chat ?= {}

class UserCommandHandler extends MessageHandler
  constructor: (@chat) ->
    @_init()
    super

  getCommands: ->
    Object.keys @_handlers

  getCommand: (command) ->
    @_handlers[command]

  listenTo: (emitter) ->
    emitter.on 'command', (e) =>
      if @canHandle e.name
        @handle e.name, e.args...

  handle: (type, args...) ->
    command = @_handlers[type]
    if not command then return super type, args...
    return unless command.canRun()
    # TODO show helpful message explaining why the command can't be run

    command.setArgs args...
    if command.hasValidArgs()
      command.run()
    else
      @chat.currentWindow.message '*', command.getHelp(), 'notice help'

  _init: ->
    @_addCommand 'join',
      description: 'joins the channel, the current channel is used by default'
      params: ['opt_channel']
      requires: ['connection', 'connected']
      parseArgs: ->
        @channel ?= @chan
      run: ->
        win = @chat._createWindowForChannel @conn, @channel
        @chat.switchToWindow win
        @conn.irc.doCommand 'JOIN', @channel

    @_addCommand 'win',
      description: 'switch windows'
      params: ['windowNum']
      parseArgs: ->
        num = parseInt @windowNum
        @window = @chat.winList.get num
      run: ->
        @chat.switchToWindow @window

    @_addCommand 'say',
      description: 'displays text in the current channel'
      params: ['text...']
      requires: ['connection', 'channel', 'connected']
      run: ->
        @conn.irc.doCommand 'PRIVMSG', @chan, @text
        @displayMessage 'privmsg', @conn.irc.nick, @text

    @_addCommand 'me',
      description: 'displays text in the current channel, spoken in the 3rd person'
      extends: 'say'
      parseArgs: ->
        @text = "\u0001ACTION #{@text}\u0001"

    @_addCommand 'nick',
      description: 'sets your nick'
      params: ['nick']
      run: ->
        @chat.previousNick = @nick
        chrome.storage.sync.set {nick: @nick}
        @chat.updateStatus()
        @conn?.irc.doCommand 'NICK', @nick

    @_addCommand 'server',
      description: 'connects to a sevrer, the default port is 6667, ' +
          "if no arguments are given it tries to reconnect to the current server"
      params: ['opt_server', 'opt_port']
      parseArgs: ->
        @port = parseInt(@port ? 6667)
        @server ?= @conn?.name
        return @port and @server
      run: ->
        @chat.connect @server, @port

    @_addCommand 'connect',
      extends: 'server'

    @_addCommand 'quit',
      description: 'disconnects from the current server'
      params: ['opt_reason...']
      requires: ['connection']
      run: ->
        if @conn.irc.state is 'reconnecting'
          @conn.irc.giveup()
        else
          @conn.irc.quit @reason ? 'Client Quit'
        @chat.removeWindow @chat.winList.get @conn.name

    @_addCommand 'names',
      description: 'lists the nicks on the current channel'
      requires: ['connection', 'channel', 'connected']
      parseArgs: ->
      run: ->
        names = (v for k,v of @conn.irc.channels[@chan].names).sort()
        msg = "Users in #{target}: #{JSON.stringify names}"
        @chat.currentWindow.message '*', msg, 'notice names'

    @_addCommand 'help',
      description: "displays information about a command, if no command is " +
          "given then lists all possible commands."
      params: ["opt_command"]
      run: ->
        @command = @chat.userCommands.getCommand @command
        if @command
          @chat.currentWindow.message '*', @command.getHelp(), 'notice help'
        else
          commands = @chat.userCommands.getCommands()
          @chat.currentWindow.displayHelp commands

    @_addCommand 'part',
      description: "closes the current window and leaves the channel if connected"
      params: ['opt_reason...']
      requires: ['connection', 'channel']
      run: ->
        @conn.irc.doCommand 'PART', @chan, @reason
        @chat.removeWindow()

    @_addCommand 'raw',
      description: "sends a raw event to the IRC server, use the -c flag to make the command apply to the current channel"
      params: ['command', 'opt_args...']
      usage: '<command> [-c] [arguments...]'
      requires: ['connection']
      parseArgs: ->
        @args = if @args then @args.split ' ' else []
      run: ->
        command = chat.customCommandParser.parse @chan, @command, @args...
        @conn.irc.doCommand command...

    @_addCommand 'load',
      description: "loads a script from the file system"
      run: ->
        script.loader.createScriptFromFileSystem (script) =>
          @chat.emit 'script_loaded', script

    @_addCommand 'topic',
      description: "sets the topic of the current channel, if there are no arguments then it displays the current topic"
      params: ['opt_topic...']
      requires: ['connection', 'channel']
      run: ->
        @conn.irc.doCommand 'TOPIC', @chan, @topic

    @_addCommand 'kick',
      description: "removes a user from the current channel"
      params: ['nick', 'opt_reason...']
      requires: ['connection', 'channel']
      run: ->
        @conn.irc.doCommand 'KICK', @chan, @nick, @reason

    @_addCommand 'mode',
      # TODO when used with no args, display current modes
      description: "sets the mode for the given user, if no nick is provides " +
          "then your nick is used"
      params: ['opt_nick', 'mode']
      requires: ['connection']
      parseArgs: ->
        @nick ?= @conn.irc.nick
      run: ->
        if @isOwnNick() and @mode in ['+o', '+O', '-r']
          @displayMessage 'error', "You can't give yourself #{@mode} status"
        else if @chan
          @conn.irc.doCommand 'MODE', @chan, @mode, @nick
        else
          @conn.irc.doCommand 'MODE', @mode, @nick

    @_addCommand 'op',
      description: "gives a user operator status"
      params: ['nick']
      extends: 'mode'
      parseArgs: -> @mode = '+o'

    @_addCommand 'deop',
      description: "removes operator status from a user"
      params: ['nick']
      extends: 'mode'
      parseArgs: -> @mode = '-o'

    @_addCommand 'voice',
      description: "gives a user voice"
      params: ['nick']
      extends: 'mode'
      parseArgs: -> @mode = '+v'

    @_addCommand 'devoice',
      description: "removes voice from a user"
      params: ['nick']
      extends: 'mode'
      parseArgs: -> @mode = '-v'

    @_addCommand 'away',
      description: "sets your current status to away, when people /msg you " +
          "or do a WHOIS on you, they will get an automatic response"
      params: ['response...']
      requires: ['connection']
      parseArgs: ->
        unless stringHasContent @response
          @response = "I'm currently away from my computer"
        true
      run: ->
        @conn.irc.doCommand 'AWAY', @response

    @_addCommand 'back',
      description: "sets your status to no longer being away"
      requires: ['connection']
      run: -> @conn.irc.doCommand 'AWAY', @response

    @_addCommand 'msg',
      description: "closes the current window and leaves the channel if connected"
      params: ['nick', 'message...']
      requires: ['connection']
      run: ->
        @conn.irc.doCommand 'PRIVMSG', @nick, @message
        @displayDirectMessage()

  _addCommand: (name, commandDescription) ->
    command = new chat.UserCommand name, commandDescription
    command.setContext @chat
    commandToExtend = @_handlers[commandDescription.extends]
    command.describe commandToExtend.description if commandToExtend
    @_handlers[name] = command

  _handlers:
    join: (opt_chan) ->
      if conn = @chat.currentWindow.conn
        return unless (conn.irc.state is 'connected')
        chan = opt_chan ? @chat.currentWindow.target
        return unless chan
        win = @chat._createWindowForChannel conn, chan
        @chat.switchToWindow win
        @chat.currentWindow.conn.irc.doCommand 'JOIN', chan

    win: (num) ->
      num = parseInt(num)
      win = @chat.winList.get num
      @chat.switchToWindow win if win?

    say: (text...) ->
      if (target = @chat.currentWindow.target) and (conn = @chat.currentWindow.conn)
        text = text.join ' '
        conn.irc.doCommand 'PRIVMSG', target, text
        @chat.displayMessage 'privmsg', conn.name, target, conn.irc.nick, text

    me: (text...) ->
      text = text.join ' '
      @chat.chatCommands.handle 'say', '\u0001ACTION '+text+'\u0001'

    nick: (newNick) ->
      @chat.previousNick = newNick
      chrome.storage.sync.set {nick: newNick}
      @chat.updateStatus()
      if conn = @chat.currentWindow.conn
        conn.irc.doCommand 'NICK', newNick

    connect: -> @handle 'server', arguments...
    server: (server, port) -> # connect to server
      server ?= @chat.currentWindow.conn?.name
      if server?
        @chat.connect server, if port then parseInt port

    quit: (reason...) ->
      return unless (conn = @chat.currentWindow.conn)
      if conn.irc.state == 'reconnecting'
        conn.irc.giveup()
      else
        reason = if reason.length is 0 then 'Client Quit' else reason.join(' ')
        conn.irc.quit reason
      @chat.removeWindow @chat.winList.get conn.name

    names: ->
      win = @chat.currentWindow
      return unless (conn = win.conn) and (target = win.target) and
          (names = conn.irc.channels[target]?.names)
      names = (v for k,v of names).sort()
      msg = "Users in #{target}: #{JSON.stringify names}"
      @chat.currentWindow.message '*', msg, 'notice names'

    help: ->
      commands = @chat.chatCommands.getCommands()
      @chat.currentWindow.displayHelp commands

    part: (reason...) ->
      win = @chat.currentWindow
      if (conn = win.conn) and (target = win.target)
        conn.irc.doCommand 'PART', target, reason.join(' ')
        @chat.removeWindow()

    raw: (args...) ->
      start = 0
      if (conn = @chat.currentWindow.conn)
        channel = @chat.currentWindow.target
        ircCommand = chat.customCommandParser.parse channel, args...
        conn.irc.doCommand ircCommand...

    load: ->
      script.loader.createScriptFromFileSystem (script) =>
        @chat.emit 'script_loaded', script

    topic: (topic...) ->
      win = @chat.currentWindow
      return unless (conn = win.conn) and (target = win.target)
      conn.irc.doCommand 'TOPIC', target, topic.join ' '

    kick: (nick, reason...) ->
      win = @chat.currentWindow
      return unless (conn = win.conn) and (chan = win.target)
      conn.irc.doCommand 'KICK', chan, nick, reason.join ' '

    ##
    # Sets the mode for the given nick. If no nick is provided, the user's nick
    # is used.
    # @param {string} opt_nick
    # @param {string} mode
    ##
    mode: (opt_nick, mode) ->
      win = @chat.currentWindow
      return unless (conn = win.conn)
      nick = opt_nick
      if arguments.length is 1
        mode = opt_nick
        nick = conn.irc.nick
      if not @_isValidModeRequest nick, mode
        @_displayErrorMessage "You can't give yourself #{mode} status"
      else if win.target
        conn.irc.doCommand 'MODE', win.target, mode, nick
      else
        conn.irc.doCommand 'MODE', mode, nick

    op: (nick) ->
      @handle 'mode', nick, '+o'

    deop: (nick) ->
      @handle 'mode', nick, '-o'

    voice: (nick) ->
      @handle 'mode', nick, '+v'

    devoice: (nick) ->
      @handle 'mode', nick, '-v'

    away: (reason...) ->
      return unless (conn = @chat.currentWindow.conn)
      reason = reason.join ' '
      if not stringHasContent reason
        reason = "I'm currently away from my computer"
      conn.irc.doCommand 'AWAY', reason

    back: ->
      return unless (conn = @chat.currentWindow.conn)
      conn.irc.doCommand 'AWAY'

    ##
    # /msg sends a direct message to another user. If their exists a private
    # chat room between the two users, the message will go there. Otherwise
    # it is displayed in the current window.
    ##
    msg: (to, message...) ->
      return unless (conn = @chat.currentWindow.conn)
      message = message.join ' '
      conn.irc.doCommand 'PRIVMSG', to, message
      @_displayDirectMessage to, message

  _displayDirectMessage: (to, message) ->
    conn = @chat.currentWindow.conn
    e = new Event 'message', 'privmsg', to, message
    e.setContext conn.name, @chat.currentWindow.target
    e.setStyle 'direct'
    @chat.emit e.type, e

  _displayErrorMessage: (msg) ->
    win = @chat.currentWindow
    return unless (conn = win.conn)
    @chat.displayMessage 'error', conn.name, win.target, msg

  _isValidModeRequest: (nick, mode) ->
    not @_isOwnNick(nick) or not (mode in ['+o', '+O', '-r'])

  _isOwnNick: (nick) ->
    irc.util.nicksEqual @chat.currentWindow.conn?.irc.nick, nick

exports.UserCommandHandler = UserCommandHandler