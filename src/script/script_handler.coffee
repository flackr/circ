exports = window.script ?= {}

class ScriptHandler extends EventEmitter
  constructor: ->
    @_frames = []
    @_commands = new script.ScriptCommandHandler()
    @_commands.setEmitCallback @_onCommand
    addEventListener 'message', @_handleMessage

  registerChatEvents: (emitter) ->
    emitter.on 'command'

  addScriptFrame: (frame) ->
    @_frames.push frame

  _handleMessage: (e) =>
    return if not @_messageFromScript e
    type = e.data.type
    if not @_commands.canHandle type
      console.warn 'script sent unknown command:', type
    else
      @_commands.handle type, e.data

  _messageFromScript: (e) ->
    for frame in @_frames
      return true if e.source == frame
    return false

  _onCommand: (commandArgs...) =>
    @emit commandArgs...

  tearDown: ->
    removeEventListener 'message', @_handleEvent


exports.ScriptHandler = ScriptHandler