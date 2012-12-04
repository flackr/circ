exports = window.script ?= {}

class Script
  constructor: (@sourceCode, @frame) ->
    @id = Script.getUniqueID()
    @_messagesToHandle = []
    @_name = "script#{@id}"

  postMessage: (msg) ->
    @frame.postMessage msg, '*'

  shouldHandle: (event) ->
    event.hook in @_messagesToHandle

  ##
  # Begin handling events of the given type and name.
  # @param {string} type The event type (command, message or server)
  # @param {string} name The name of the event (e.g. kick, NICK, privmsg, etc)
  ##
  beginHandlingType: (type, name) ->
    @_messagesToHandle.push type + ' ' + name

  @getScriptFromFrame: (scripts, frame) ->
    for id, script of scripts
      return script if script.frame == frame
    return undefined

  @scriptCount: 0

  @getUniqueID: ->
    return @scriptCount++

  setName: (@_name) ->

  getName: ->
    @_name

exports.Script = Script