exports = window.chat ?= {}

##
# Represents a user command, like /kick or /say.
##
class UserCommand
  constructor: (name, @description) ->
    @name = name
    @describe @description
    @_hasValidArgs = false

  ##
  # Describe the command using the following format:
  # * description - a description of what the command does; used with /help
  #       <command>
  # * category - what category the command falls under. This is used with /help
  # * params - what parameters the command takes, 'opt_<name>' for optional,
  #       '<name>...' for variable
  # * validateArgs - returns a truthy variable if the given arguments are valid.
  # * requires - what the command requires to run (e.g. a connections to an IRC
  #       server)
  # * usage - manually set a usage message, one will be generated if not specified
  # * run - the function to call when the command is run
  ##
  describe: (description) ->
    @_description ?= description.description
    @_params ?= description.params
    @_requires ?= description.requires
    @_validateArgs ?= description.validateArgs
    @_usage ?= description.usage
    @run ?= description.run
    @category ?= description.category

  ##
  # Try running the command. A command can fail to run if its requirements
  # aren't met (e.g. needs a connection to the internet) or the specified
  # arguments are invalid. In these cases a help message is displayed.
  # @param {Context} context Which server/channel the command came from.
  # @param {Object...} args Arguments for the command.
  ##
  tryToRun: (context, args...) ->
    @setContext context
    if not @canRun()
      if @shouldDisplayFailedToRunMessage()
        @displayHelp()
      return

    @setArgs args...
    if @_hasValidArgs
      @run()
    else
      @displayHelp()

  setChat: (@chat) ->

  setContext: (context) ->
    @win = @chat.determineWindow context
    unless @win is window.chat.NO_WINDOW
      @conn = @win.conn
      @chan = @win.target

  setArgs: (args...) ->
    @_hasValidArgs = @_tryToAssignArgs(args) and
        (not @_validateArgs or !!@_validateArgs())

  _tryToAssignArgs: (args) ->
    @_removeTrailingWhiteSpace args
    if not @_params
      return args.length is 0

    @_resetParams()
    @_truncateVariableArgs args
    params = @_truncateExtraOptionalParams args.length
    return false unless args.length is params.length

    for param, i in params
      this[@_getParamName param] = args[i]
    return true

  _resetParams: ->
    for param in @_params
      this[@_getParamName param] = undefined

  _removeTrailingWhiteSpace: (args) ->
    for i in [args.length-1..0]
      if args[i] is ''
        args.splice i, 1
      else break

  ##
  # Join all arguments that fit under the variable argument param.
  # Note: only the last argument is allowd to be variable.
  ##
  _truncateVariableArgs: (args) ->
    return args if args.length < @_params.length
    if @_isVariable @_params[@_params.length-1]
      args[@_params.length - 1] = args[@_params.length - 1..]?.join ' '
      args.length = @_params.length

  _truncateExtraOptionalParams: (numArgs) ->
    extraParams = @_params.length - numArgs
    return @_params if extraParams <= 0
    params = []
    for i in [@_params.length-1..0]
      param = @_params[i]
      if extraParams > 0 and @_isOptional param
        extraParams--
      else
        params.splice 0, 0, param
    return params

  ##
  # When a command can't run, determine if a helpful message should be
  # displayed to the user.
  ##
  shouldDisplayFailedToRunMessage: ->
    return false if @win is window.chat.NO_WINDOW
    return @name isnt 'say'

  ##
  # Commands can only run if their requirements are met (e.g. connected to the
  # internet, in a channel, etc) and a run method is defined.
  ##
  canRun: (opt_context) ->
    @setContext opt_context if opt_context
    return false if not @run
    return true if not @_requires
    for requirement in @_requires
      return false if not @_meetsRequirement requirement
    return true

  _meetsRequirement: (requirement) ->
    switch requirement
      when 'online' then isOnline()
      when 'connection' then !!@conn and isOnline()
      when 'channel' then !!@chan
      else @conn?.irc.state is requirement

  displayHelp: (win=@win) ->
    win.message '', @getHelp(), 'notice help'

  getHelp: ->
    descriptionText = if @_description then ", #{@_description}" else ''
    usageText = ' ' + @_usage if @_usage
    usageText ?= if @_params?.length > 0 then " #{@_getUsage()}" else ''
    return @name.toUpperCase() + usageText + descriptionText + '.'

  _getUsage: ->
    paramDescription = []
    for param in @_params
      paramName = @_getParamName param
      if @_isOptional param
        paramName = "[#{paramName}]"
      else
        paramName = "<#{paramName}>"
      paramDescription.push paramName
    return paramDescription.join ' '

  _getParamName: (param) ->
    if @_isOptional param
      param = param[4..]
    if @_isVariable param
      param = param[..param.length - 4]
    return param

  _isOptional: (param) ->
    return param.indexOf('opt_') is 0

  _isVariable: (param) ->
    param?[param.length-3..] is '...'

  isOwnNick: (nick=@nick) ->
    irc.util.nicksEqual @conn?.irc.nick, nick

  displayDirectMessage: (nick=@nick, message=@message) ->
    if @conn?.windows[nick]?
      @_displayDirectMessageInPrivateChannel nick, message
    else
      @_displayDirectMessageInline nick, message

  ##
  # Used with /msg. Displays the message in a private channel.
  ##
  _displayDirectMessageInPrivateChannel: (nick, message) ->
    context = { server: @conn.name, channel: nick }
    @chat.displayMessage 'privmsg', context, @conn.irc.nick, message

  ##
  # Used with /msg. Displays the private message in the current window.
  # Direct messages always display inline until the user receives a response.
  ##
  _displayDirectMessageInline: (nick, message) ->
    @displayMessageWithStyle 'privmsg', nick, message, 'direct'

  displayMessage: (type, args...) ->
    context = { server: @conn?.name, channel: @chan }
    @chat.displayMessage type, context, args...

  ##
  # Displays a message with a custom style. This is useful for indicating that
  # a message be rendered in a special way (e.g. no pretty formatting).
  ##
  displayMessageWithStyle: (type, args..., style) ->
    e = new Event 'message', type, args...
    e.setContext @conn?.name, @chan
    e.addStyle style
    @chat.emit e.type, e

  handleCTCPRequest: (nick, type) ->
    @displayDirectMessage @nick, "CTCP #{type}"
    delimiter = irc.CTCPHandler.DELIMITER
    message = delimiter + type + delimiter
    @conn.irc.doCommand 'PRIVMSG', @nick, message

exports.UserCommand = UserCommand