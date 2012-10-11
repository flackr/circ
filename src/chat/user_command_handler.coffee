exports = window.chat ?= {}

class UserCommandHandler extends MessageHandler
  constructor: (@chat) ->
    @_handlers = {}
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

    if not command.canRun()
      @_displayHelp command unless command.name is 'say'
      return

    command.setArgs args...
    if command.hasValidArgs()
      command.run()
    else
      @_displayHelp command

  _displayHelp: (command) ->
    @chat.currentWindow.message '*', command.getHelp(), 'notice help'

  _init: ->
    @_addCommand 'join',
      description: 'joins the channel, the current channel is used by default'
      params: ['opt_channel']
      requires: ['connection']
      parseArgs: ->
        @channel ?= @chan
      run: ->
        @chat.join @conn, @channel

    @_addCommand 'part',
      description: "closes the current window and disconnects from the channel"
      params: ['opt_reason...']
      requires: ['connection', 'channel']
      run: ->
        unless @chat.currentWindow.isPrivate()
          @conn.irc.part @chan, @reason
        @chat.removeWindow()

    @_addCommand 'win',
      description: 'switches windows'
      params: ['windowNum']
      parseArgs: ->
        @windowNum = parseInt @windowNum
      run: ->
        @chat.switchToWindowByIndex @windowNum

    @_addCommand 'say',
      description: 'sends text to the current channel'
      params: ['text...']
      requires: ['connection', 'channel', 'connected']
      run: ->
        @conn.irc.doCommand 'PRIVMSG', @chan, @text
        @displayMessage 'privmsg', @conn.irc.nick, @text

    @_addCommand 'me',
      description: 'sends text to the current channel, spoken in the 3rd person'
      extends: 'say'
      parseArgs: ->
        @text = "\u0001ACTION #{@text}\u0001"

    @_addCommand 'nick',
      description: 'sets your nick'
      params: ['nick']
      run: ->
        @chat.previousNick = @nick
        @chat.syncStorage.nickChanged @nick
        @chat.updateStatus()
        @conn?.irc.doCommand 'NICK', @nick

    @_addCommand 'server',
      description: 'connects to the server, port 6667 is used by default, ' +
          "reconnects to the current server if no server is specified"
      params: ['opt_server', 'opt_port']
      parseArgs: ->
        @port ?= parseInt(@server) || 6667
        @port = parseInt(@port)
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
      description: 'lists nicks in the current channel'
      requires: ['connection', 'channel', 'connected']
      run: ->
        if @chat.currentWindow.isPrivate()
          msg = "You're in a private conversation with #{@chan}."
        else
          names = (v for k,v of @conn.irc.channels[@chan].names).sort()
          msg = "Users in #{@chan}: #{JSON.stringify names}"
        @chat.currentWindow.message '*', msg, 'notice names'

    @_addCommand 'help',
      description: "displays information about a command, lists all commands " +
          "if no command is specified"
      params: ["opt_command"]
      run: ->
        @command = @chat.userCommands.getCommand @command
        if @command
          @chat.currentWindow.message '*', @command.getHelp(), 'notice help'
        else
          commands = @chat.userCommands.getCommands()
          @chat.currentWindow.displayHelp commands

    @_addCommand 'raw',
      description: "sends a raw event to the IRC server, use the -c flag to " +
          "make the command apply to the current channel"
      params: ['command', 'opt_args...']
      usage: '<command> [-c] [arguments...]'
      requires: ['connection']
      parseArgs: ->
        @args = if @args then @args.split ' ' else []
      run: ->
        command = chat.customCommandParser.parse @chan, @command, @args...
        @conn.irc.doCommand command...

    @_addCommand 'load',
      description: "loads a script by opening a file browser dialog"
      run: ->
        script.loader.createScriptFromFileSystem (script) =>
          @chat.emit 'script_loaded', script

    @_addCommand 'topic',
      description: "sets the topic of the current channel, displays the " +
          "current topic if no topic is specified"
      params: ['opt_topic...']
      requires: ['connection', 'channel']
      run: ->
        @conn.irc.doCommand 'TOPIC', @chan, @topic

    @_addCommand 'kick',
      description: "removes the nick from the current channel"
      params: ['nick', 'opt_reason...']
      requires: ['connection', 'channel']
      run: ->
        @conn.irc.doCommand 'KICK', @chan, @nick, @reason

    @_addCommand 'mode',
      # TODO when used with no args, display current modes
      description: "sets the mode for the given user, your nick is used if " +
          "no nick is specified"
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
      description: "gives operator status"
      params: ['nick']
      extends: 'mode'
      parseArgs: -> @mode = '+o'

    @_addCommand 'deop',
      description: "removes operator status"
      params: ['nick']
      extends: 'mode'
      parseArgs: -> @mode = '-o'

    @_addCommand 'voice',
      description: "gives voice"
      params: ['nick']
      extends: 'mode'
      parseArgs: -> @mode = '+v'

    @_addCommand 'devoice',
      description: "removes voice"
      params: ['nick']
      extends: 'mode'
      parseArgs: -> @mode = '-v'

    @_addCommand 'away',
      description: "sets your status to away, a response is " +
          "automatically sent when people /msg or WHOIS you"
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
      description: "sends a private message"
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

exports.UserCommandHandler = UserCommandHandler