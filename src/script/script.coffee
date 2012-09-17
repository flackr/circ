exports = window.script ?= {}

class Script
  constructor: (@sourceCode, @frame) ->
    @id = Script.getUniqueID()
    @hookedCommands = []

  postMessage: (msg) ->
    @frame.postMessage msg, '*'

  @getScriptFromFrame: (scripts, frame) ->
    for id, script of scripts
      return script if script.frame == frame
    return undefined

  @scriptCount: 0

  @getUniqueID: ->
    return @scriptCount++

exports.Script = Script