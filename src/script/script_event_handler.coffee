exports = window.script ?= {}

class ScriptEventHandler extends MessageHandler

  constructor: ->
    super
    @registerHandlers @_events

  setCallback: (@_onEvent) ->

  _events:
    switched_window: (server, chan) ->

    command: (command, args...) ->

    message: (chan, server, from, text) ->

    scrolled_off_top: (from, text) ->

exports.ScriptEventHandler = ScriptEventHandler