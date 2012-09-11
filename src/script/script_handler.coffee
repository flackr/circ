exports = window.script ?= {}

class ScriptHandler
  constructor: ->
    @_frames = []

  addScriptFrame: (frame) ->
    @_frames.push frame
    frame.postMessage { type: 'startup' }, '*'

exports.ScriptHandler = ScriptHandler