exports = window.script ?= {}

class Script
  constructor: (@source, @frame) ->
    @id = Script.getUniqueID()
    @hookedCommands = []

  postMessage: (msg) ->
    @frame.postMessage msg, '*'

  @getScriptFromFrame: (scripts, frame) ->
    for id, script of scripts
      return script if scripts.frame == frame
    return undefined

  @scriptCount: 0

  @getUniqueID: ->
    return @scriptCount++

exports.Script = Script