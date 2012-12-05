exports = window.chat ?= {}

##
# Handles user commands, including providing help messages and determining if a
# command can be run in the current context.
##
class UserCommandHandler extends MessageHandler
  constructor: (@chat) ->
    @_handlers = {}
    @_init()
    super

  getCommands: ->
    @_handlers

  getCommand: (command) ->
    @_handlers[command]

  listenTo: (emitter) ->
    emitter.on 'command', (e) =>
      if @canHandle e.name
        @handle e.name, e, e.args...

  handle: (type, context, args...) ->
    if not @_isValidUserCommand type
      # the command must be a developer command
      super type, context, args...
      return
    command = @_handlers[type]
    command.tryToRun context, args...

  _isValidUserCommand: (type) ->
    type of @_handlers

  ##
  # Creates all user commands. The "this" parameter in the run() and
  # validateArgs() functions is UserCommand.
  # @this {UserCommand}
  ##
  _init: ->
    @_addCommand 'nick',
      description: 'sets your nick'
      category: 'common'
      params: ['nick']
      run: ->
        @chat.setNick @conn?.name, @nick

    @_addCommand 'server',
      description: 'connects to the server, port 6667 is used by default, ' +
          "reconnects to the current server if no server is specified"
      category: 'common'
      params: ['opt_server', 'opt_port']
      requires: ['online']
      validateArgs: ->
        if @port then @port = parseInt @port
        else @port = 6667
        @server ?= @conn?.name
        return @server and not isNaN @port
      run: ->
        @chat.connect @server, @port

    @_addCommand 'join',
      description: 'joins the channel, reconnects to the current channel ' +
          'if no channel is specified'
      category: 'common'
      params: ['opt_channel']
      requires: ['connection']
      validateArgs: ->
        @channel ?= @chan # use the current channel if no channel is specified
        @channel = @channel.toLowerCase()
      run: ->
        @chat.join @conn, @channel

    @_addCommand 'part',
      description: "closes the current window and disconnects from the channel"
      category: 'common'
      params: ['opt_reason...']
      requires: ['connection', 'channel']
      run: ->
        unless @win.isPrivate()
          @conn.irc.part @chan, @reason
        @chat.removeWindow(@win)

    @_addCommand 'win',
      description: 'switches windows, only channel windows are selected this way'
      category: 'misc'
      params: ['windowNum']
      validateArgs: ->
        @windowNum = parseInt @windowNum
        not isNaN @windowNum
      run: ->
        @chat.switchToChannelByIndex @windowNum - 1

    @_addCommand 'say',
      description: 'sends text to the current channel'
      category: 'uncommon'
      params: ['text...']
      requires: ['connection', 'channel', 'connected']
      run: ->
        @conn.irc.doCommand 'PRIVMSG', @chan, @text
        @displayMessage 'privmsg', @conn.irc.nick, @text

    @_addCommand 'me',
      description: 'sends text to the current channel, spoken in the 3rd person'
      category: 'uncommon'
      extends: 'say'
      validateArgs: ->
        @text = "\u0001ACTION #{@text}\u0001"

    @_addCommand 'quit',
      description: 'disconnects from the current server'
      category: 'common'
      params: ['opt_reason...']
      requires: ['connection']
      run: ->
        @chat.closeConnection @conn

    @_addCommand 'names',
      description: 'lists nicks in the current channel'
      category: 'uncommon'
      requires: ['connection', 'channel', 'connected']
      run: ->
        if @win.isPrivate()
          msg = "You're in a private conversation with #{@chan}."
        else
          names = (v for k,v of @conn.irc.channels[@chan].names).sort()
          msg = "Users in #{@chan}: #{JSON.stringify names}"
        @win.message '', msg, 'notice names'

    @_addCommand 'help',
      description: "displays information about a command, lists all commands " +
          "if no command is specified"
      category: 'misc'
      params: ["opt_command"]
      run: ->
        @command = @chat.userCommands.getCommand @command
        if @command
          @command.displayHelp @win
        else
          commands = @chat.userCommands.getCommands()
          @win.messageRenderer.displayHelp commands

    @_addCommand 'raw',
      description: "sends a raw event to the IRC server, use the -c flag to " +
          "make the command apply to the current channel"
      category: 'uncommon'
      params: ['command', 'opt_arguments...']
      usage: '<command> [-c] [arguments...]'
      requires: ['connection']
      validateArgs: ->
        @arguments = if @arguments then @arguments.split ' ' else []
      run: ->
        command = chat.customCommandParser.parse @chan, @command, @arguments...
        @conn.irc.doCommand command...

    @_addCommand 'install',
      description: "loads a script by opening a file browser dialog"
      category: 'scripts'
      run: ->
        script.loader.createScriptFromFileSystem (script) =>
          @chat.addScript script

    @_addCommand 'uninstall',
      description: "uninstalls a script, currently installed scripts can be listed with /scripts"
      params: ['scriptName']
      usage: '<script name>'
      category: 'scripts'
      run: ->
        script = @chat.scriptHandler.getScriptByName @scriptName
        if script
          @chat.scriptHandler.removeScript script
          @chat.storage.scriptRemoved script
          @displayMessage 'notice', "Script #{@scriptName} was successfully uninstalled"
        else
          message = "No script by the name '#{@scriptName}' was found. #{@listInstalledScripts()}"
          @displayMessage 'error', message

    @_addCommand 'scripts',
      description: "displays a list of installed scripts"
      category: 'scripts'
      run: ->
        @displayMessage 'notice', @listInstalledScripts()

    @_addCommand 'topic',
      description: "sets the topic of the current channel, displays the " +
          "current topic if no topic is specified"
      category: 'uncommon'
      params: ['opt_topic...']
      requires: ['connection', 'channel']
      run: ->
        @conn.irc.doCommand 'TOPIC', @chan, @topic

    @_addCommand 'kick',
      description: "removes a user from the current channel"
      category: 'uncommon'
      params: ['nick', 'opt_reason...']
      requires: ['connection', 'channel']
      run: ->
        @conn.irc.doCommand 'KICK', @chan, @nick, @reason

    @_addCommand 'mode',
      # TODO when used with no args, display current modes
      description: "sets or gets the modes of a channel or user(s), the " +
          "current channel is used by default"
      category: 'uncommon'
      params: ['opt_target', 'opt_mode', 'opt_nicks...']
      usage: "< [channel|nick] | [channel] <mode> [nick1] [nick2] ...>"
      requires: ['connection']
      validateArgs: ->
        return true if @args.length is 0
        @nicks = @nicks?.split(' ') ? []
        return true if @args.length is 1 and not @isValidMode(@target)

        if @isValidMode(@target) and @target isnt @chan
          # a target wasn't specified, shift variables over by one
          @nicks.push @mode
          @mode = @target
          @target = @chan
        return @target and @isValidMode @mode

      run: ->
        if @args.length is 0
          @conn.irc.doCommand 'MODE', @chan if @chan
          @conn.irc.doCommand 'MODE', @conn.irc.nick
        else
          @conn.irc.doCommand 'MODE', @target, @mode, @nicks...

    @_addCommand 'op',
      description: "gives operator status"
      params: ['nick']
      extends: 'mode'
      usage: "<nick>"
      requires: ['connection', 'channel']
      validateArgs: ->
        @setModeArgs '+o'

    @_addCommand 'deop',
      description: "removes operator status"
      params: ['nick']
      extends: 'mode'
      usage: "<nick>"
      requires: ['connection', 'channel']
      validateArgs: ->
        @setModeArgs '-o'

    @_addCommand 'voice',
      description: "gives voice"
      params: ['nick']
      extends: 'mode'
      usage: "<nick>"
      requires: ['connection', 'channel']
      validateArgs: ->
        @setModeArgs '+v'

    @_addCommand 'devoice',
      description: "removes voice"
      params: ['nick']
      extends: 'mode'
      usage: "<nick>"
      requires: ['connection', 'channel']
      validateArgs: ->
        @setModeArgs '-v'

    @_addCommand 'away',
      description: "sets your status to away, a response is " +
          "automatically sent when people /msg or WHOIS you"
      category: 'uncommon'
      params: ['opt_response...']
      requires: ['connection']
      validateArgs: ->
        unless stringHasContent @response
          @response = "I'm currently away from my computer"
        true
      run: ->
        @conn.irc.doCommand 'AWAY', @response

    @_addCommand 'back',
      description: "sets your status to no longer being away"
      category: 'uncommon'
      requires: ['connection']
      run: -> @conn.irc.doCommand 'AWAY', @response

    @_addCommand 'msg',
      description: "sends a private message"
      category: 'common'
      params: ['nick', 'message...']
      requires: ['connection']
      run: ->
        @conn.irc.doCommand 'PRIVMSG', @nick, @message
        @displayDirectMessage()

    @_addCommand 'about',
      description: "displays information about this IRC client"
      category: 'misc'
      run: ->
        @win.messageRenderer.displayAbout()

    @_addCommand 'join-server',
      description: "use the IRC connection of another device, allowing you " +
          "to be logged in with the same nick on multiple devices. " +
          "Connects to the device that called /make-server if no arguments " +
          "are given"
      category: 'one_identity'
      requires: ['online']
      params: ['opt_addr', 'opt_port']
      validateArgs: ->
        parsedPort = parseInt(@port)
        return false if (@port || @addr) and not (parsedPort || @addr)
        connectInfo = @chat.storage.serverDevice
        @port = parsedPort || connectInfo?.port
        @addr ?= connectInfo?.addr
        true
      run: ->
        if @port and @addr
          if @addr is @chat.remoteConnection.getConnectionInfo().addr
            @displayMessage 'error', "this device is the server and cannot " +
                "connect to itself. Call /join-server on other devices to " +
                "have them connect to this device or call /make-server on " +
                "another device to make it the server"
          else
            @chat.remoteConnectionHandler.isManuallyConnecting()
            @chat.remoteConnection.connectToServer { port: @port, addr: @addr }
        else
          @displayMessage 'error', "No server exists. Use /make-server " +
              "on the device you wish to become the server."

    @_addCommand 'make-server',
      description: "makes this device a server to which other devices can " +
          "connect. Connected devices use the IRC connection of this device"
      category: 'one_identity'
      requires: ['online']
      run: ->
        state = @chat.remoteConnection.getState()
        if @chat.remoteConnectionHandler.shouldBeServerDevice()
          @displayMessage 'error', "this device is already acting as a " +
              "server"
        else if not api.listenSupported()
          @displayMessage 'error', "this command cannot be used with your " +
              "current version of Chrome because it does not support " +
              "chrome.socket.listen"
        else if state is 'no_addr'
          @displayMessage 'error', "this device can not be used as a " +
              "server at this time because it cannot find its own IP address"
        else if state is 'no_port'
          @displayMessage 'error', "this device can not be used as a " +
              "server at this time because no valid port was found"
        else if state is 'finding_port'
          @chat.remoteConnection.waitForPort => @run
        else
          @chat.storage.becomeServerDevice @chat.remoteConnection.getConnectionInfo()
          @chat.remoteConnectionHandler.determineConnection()

    @_addCommand 'network-info',
      description: "displays network information including " +
          "port, ip address and remote connection status"
      category: 'one_identity'
      run: ->
        @displayMessage 'breakgroup'
        if @chat.remoteConnection.isServer()
          numClients = @chat.remoteConnection.devices.length
          if numClients > 0
            @displayMessage 'notice', "acting as a server for " +
                @chat.remoteConnection.devices.length + " other " +
                pluralize 'device', @chat.remoteConnection.devices.length
          else
            @displayMessage 'notice', "Acting as a server device. No clients " +
                "have connected."

        else if @chat.remoteConnection.isClient()
          @displayMessage 'notice', "connected to server device " +
              @chat.remoteConnection.serverDevice.addr + " on port " +
              @chat.remoteConnection.serverDevice.port

        else
          @displayMessage 'notice', "not connected to any other devices"

        state = @chat.remoteConnection.getConnectionInfo().getState()
        return unless state is 'found_port'
        @displayMessage 'breakgroup'
        connectionInfo = @chat.remoteConnection.getConnectionInfo()
        @displayMessageWithStyle 'notice', "Port: #{connectionInfo.port}", 'no-pretty-format'
        @displayMessage 'breakgroup'
        @displayMessage 'notice', "IP addresses:"
        for addr in connectionInfo.possibleAddrs
          @displayMessageWithStyle 'notice', "    #{addr}", 'no-pretty-format'

    @_addCommand 'autostart',
      description: "sets whether the application will run on startup, " +
          "toggles if no arguments are given"
      category: 'misc'
      usage: '[ON|OFF]'
      params: ['opt_state']
      validateArgs: ->
        unless @state
          @enabled = undefined
          return true
        @state = @state.toLowerCase()
        return false unless @state is 'on' or @state is 'off'
        @enabled = @state is 'on'
        true
      run: ->
        willAutostart = @chat.storage.setAutostart @enabled
        if willAutostart
          @displayMessage 'notice', "CIRC will now automatically " +
              "run on startup"
        else
          @displayMessage 'notice', "CIRC will no longer " +
              "automatically run on startup"

    @_addCommand 'query',
      description: 'opens a new window for a private conversation with someone'
      category: 'uncommon'
      params: ['nick']
      requires: ['connection']
      run: ->
        win = @chat.createPrivateMessageWindow @conn, @nick
        @chat.switchToWindow win

    @_addCommand 'kill',
      description: 'kicks a user from the server'
      category: 'uncommon'
      params: ['nick', 'opt_reason']
      requires: ['connection']
      run: ->
        @conn.irc.doCommand 'KILL', @nick, @reason

    @_addCommand 'version',
      description: "get the user's IRC version"
      category: 'uncommon'
      params: ['nick']
      requires: ['connection']
      run: ->
        @handleCTCPRequest @nick, 'VERSION'

    @_addCommand 'ignore',
      description: "stop certain message(s) from being displayed in the " +
          "current channel, for example '/ignore join part' stops join " +
          "and part messages from being displayed, a list of ignored " +
          "messages is displayed if no arguments are given"
      category: 'misc'
      params: ['opt_types...']
      requires: ['connection']
      usage: '[<message type 1> <message type 2> ...]'
      run: ->
        context = @win.getContext()
        if @types
          types = @types.split ' '
          for type in types
            @chat.messageHandler.ignoreMessageType context, type
          @displayMessage 'notice', "Messages of type " +
              "#{getReadableList types} will no longer be displayed in this " +
              "room."
        else
          typeObject = @chat.messageHandler.getIgnoredMessages()[context]
          types = (type for type of typeObject)
          if types and types.length > 0
            @displayMessage 'notice', "Messages of type " +
                "#{getReadableList types} are being ignored in this room."
          else
            @displayMessage 'notice', "There are no messages being ignored " +
                "in this room."

    @_addCommand 'unignore',
      description: "stop ignoring certain message(s)"
      extends: 'ignore'
      usage: '<message type 1> <message type 2> ...'
      run: ->
        context = @win.getContext()
        types = @types.split ' '
        for type in types
          @chat.messageHandler.stopIgnoringMessageType @win.getContext(), type
        @displayMessage 'notice', "Messages of type #{getReadableList types} " +
            "are no longer being ignored."

    ##
    # Hidden commands.
    # These commands don't display in /help or autocomplete. They're used for
    # scripts and keyboard shortcuts.
    ##
    @_addCommand 'next-server',
      description: "switches to the next server window"
      category: 'hidden'
      run: ->
        return if @win is window.chat.NO_WINDOW
        winList = @chat.winList
        server = winList.getServerForWindow @win
        return unless server
        serverIndex = winList.serverIndexOf server
        nextServer = winList.getServerWindow(serverIndex + 1) ?
            winList.getServerWindow(0)
        @chat.switchToWindow nextServer

    @_addCommand 'next-room',
      description: "switches to the next window"
      category: 'hidden'
      run: ->
        return if @win is window.chat.NO_WINDOW
        winList = @chat.winList
        index = winList.indexOf @win
        return if index < 0
        nextWin = winList.get(index + 1) ? winList.get(0)
        @chat.switchToWindow nextWin

    @_addCommand 'previous-room',
      description: "switches to the next window"
      category: 'hidden'
      run: ->
        return if @win is window.chat.NO_WINDOW
        winList = @chat.winList
        index = winList.indexOf @win
        return if index < 0
        nextWin = winList.get(index - 1) ? winList.get(winList.length - 1)
        @chat.switchToWindow nextWin

    @_addCommand 'reply',
      description: "begin replying to the user who last mentioned your nick"
      category: 'hidden'
      run: ->
        return if @win is window.chat.NO_WINDOW
        user = @chat.getLastUserToMention @win.getContext()
        return unless user
        @chat.emit 'set_input', "#{user}: "

  _addCommand: (name, commandDescription) ->
    command = new chat.UserCommand name, commandDescription
    commandToExtend = @_handlers[commandDescription.extends]
    command.describe commandToExtend.description if commandToExtend
    command.setChat @chat
    @_handlers[name] = command

exports.UserCommandHandler = UserCommandHandler
