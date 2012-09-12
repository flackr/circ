exports = window.script ?= {}

class ScriptHandler extends EventEmitter
  constructor: ->
    @_frames = []
    @_commands = new script.ScriptCommandHandler()
    @_commands.setEmitCallback @_onCommand
    addEventListener 'message', @_handleEvent

  addScriptFrame: (frame) ->
    @_frames.push frame
    frame.postMessage { type: 'startup' }, '*'

  _handleEvent: (e) =>
    type = e.data.type
    if not @_commands.canHandle type
      console.warn 'script sent unknown command:', type
    else
      @_commands.handle type, e.data

  _onCommand: (args...) =>

  tearDown: ->
    removeEventListener 'message', @_handleEvent


exports.ScriptHandler = ScriptHandler