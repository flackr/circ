exports = window.script ?= {}

class ScriptCommandHandler extends MessageHandler

  constructor: ->
    super
    @registerHandlers @_commands

  setCallback: (@_onCommand) ->

  handle: (@_type, args...) ->
    @_checksPassed = true
    assert args[0].type is @_type
    super @_type, args...

  _commands:
    register_command: (args) ->
      @_sendCommand args, 'command'

    input: (args) ->
      @_sendCommand args, 'channel', 'server', 'input'

    notify: (args) ->
      @_sendCommand args, 'title', 'body', 'id', 'timeout'

  _sendCommand: (argObj, params...) ->
    (@_check argObj[param]? for param in params)
    return unless @_checksPassed
    a = [argObj.type, (argObj[param] for param in params)...]
    @_onCommand argObj.type, (argObj[param] for param in params)...

  _check: (cond) ->
    return if cond or not @_checksPassed
    console.warn 'script command', @_type, 'was malformated'
    @_checksPassed = false

exports.ScriptCommandHandler = ScriptCommandHandler