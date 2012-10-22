exports = window.chat ?= {}

class UserCommand
  constructor: (name, @description) ->
    @name = name
    @describe @description
    @_validArgs = false

  describe: (description) ->
    @_description ?= description.description
    @_params ?= description.params
    @_requires ?= description.requires
    @_parseArgs ?= description.parseArgs
    @_usage ?= description.usage
    @run ?= description.run

  setContext: (@chat, context) ->
    @win = @chat.determineWindow context
    unless @win is window.chat.NO_WINDOW
      @conn = @win.conn
      @chan = @win.target

  setArgs: (args...) ->
    @_validArgs = @_tryToAssignArgs args
    @_validArgs = !!@_parseArgs() if @_validArgs and @_parseArgs

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

  canRun: (opt_chat, opt_context) ->
    @setContext opt_chat, opt_context if opt_chat and opt_context
    return false if not @run
    return true if not @_requires
    for requirement in @_requires
      return false if not @_meetsRequirement requirement
    return true

  _meetsRequirement: (requirement) ->
    switch requirement
      when 'connection' then !!@conn
      when 'channel' then !!@chan
      else @conn?.irc.state is requirement

  hasValidArgs: ->
    @_validArgs

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

  _displayDirectMessageInPrivateChannel: (nick, message) ->
    context = { server: @conn.name, channel: nick }
    @chat.displayMessage 'privmsg', context, @conn.irc.nick, message

  _displayDirectMessageInline: (nick, message) ->
    @displayMessageWithStyle 'privmsg', nick, message, 'direct'

  displayMessage: (type, args...) ->
    context = { server: @conn?.name, channel: @chan }
    @chat.displayMessage type, context, args...

  displayMessageWithStyle: (type, args..., style) ->
    e = new Event 'message', type, args...
    e.setContext @conn?.name, @chan
    e.addStyle style
    @chat.emit e.type, e

exports.UserCommand = UserCommand