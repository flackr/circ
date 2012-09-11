exports = window.script ?= {}

class ScriptHandler extends EventEmitter
  constructor: ->
    @_frames = []
    @_commands = new script.ScriptCommands()
    @_commands.setEmitCallback (args...) => @emit args...
    addEventListener 'message', @_handleEvent e

  addScriptFrame: (frame) ->
    @_frames.push frame
    frame.postMessage { type: 'startup' }, '*'

  _handleEvent: (e) =>
    type = e.data.type
    if not @_commands.canHandle type
      console.warn 'script sent unknown command:', type
    else
      @_commands.handle type, e.data

exports.ScriptHandler = ScriptHandler