exports = window.script ?= {}

class ScriptHandler extends EventEmitter
  constructor: ->
    super
    @_scripts = {}
    @_pendingEvents = {}
    @_eventCount = 0
    @_emitters = []
    @_hookableEvents = [ 'command', 'server', 'message' ]
    addEventListener 'message', @_handleMessage

  listenToScriptEvents: (emitter) ->
    emitter.on 'script_loaded', @addScript

  addScript: (script) =>
    @_scripts[script.id] = script

  on: (ev, cb) ->
    if not (ev in @_hookableEvents)
      @_forwardEvent ev, cb
    else
      super ev, cb

  _forwardEvent: (ev, cb) ->
    for emitter in @_emitters
      emitter.on ev, cb

  addEventsFrom: (emitter) ->
    @_emitters.push emitter
    for event in @_hookableEvents
      emitter.on event, @_handleEvent

  _handleEvent: (e) =>
    id = @_eventCount++
    e.id = id
    assert not (id of @_pendingEvents)
    for sid, script of @_scripts when e.hook in script.hookedMessages
      script.postMessage e
      @_pendingEvents[id] ?= {}
      @_pendingEvents[id].scripts ?= []
      @_pendingEvents[id].scripts.push script
      @_pendingEvents[id].event ?= e
    if not (id of @_pendingEvents)
      @emit e.type, e

  _handleMessage: (message) =>
    e = message.data
    script = window.script.Script.getScriptFromFrame @_scripts, message.source
    return unless script?
    switch e.type
      when 'hook_command', 'hook_server', 'hook_message'
        script.hookedMessages.push e.type[5..] + ' ' + e.name

      when 'propagate'
        id = e.args?[0]
        scripts = @_pendingEvents[id]?.scripts
        pendingEvent = @_pendingEvents[id]?.event
        return unless scripts? and pendingEvent? and script in scripts
        if e.name is 'none'
          delete @_pendingEvents[id]
        else if e.name is 'all'
          removeFromArray scripts, script
          if scripts.length == 0
            delete @_pendingEvents[id]
            @emit pendingEvent.type, pendingEvent
        else
          console.warn 'received unknown propagation type:', e.name

      when 'command', 'sevrer', 'message'
        # TODO add the script id to a blacklist so we don't go into a loop
        # TODO check args for correctness
        @_handleEvent Event.wrap(e)

  tearDown: ->
    removeEventListener 'message', @_handleEvent

exports.ScriptHandler = ScriptHandler