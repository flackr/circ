exports = window.script ?= {}

class ScriptHandler extends EventEmitter
  constructor: ->
    super
    @_scripts = {}
    @_pendingEvents = {}
    @_eventCount = 0
    @_emitters = []
    @_hookableEvents = [ 'command', 'server' ]
    addEventListener 'message', @_handleMessage

  addScript: (script) ->
    @_scripts[script.id] = script

  on: (ev, cb) ->
    if not (ev in @_hookableEvents)
      @_forwardEvent ev, cb
    else
      super ev, cb

  _forwardEvent: (ev, cb) ->
    for emitter in @_emitters
      emitter.on ev, cb

  intercept: (emitter) =>
    @_emitters.push emitter
    for event in @_hookableEvents
      emitter.on event, @_handleEvent
    this

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
        script.hookedMessages.push e.type[5..] + e.name

      when 'propagation'
        id = e.id
        scripts = @_pendingEvents[id]?.scripts
        pendingEvent = @_pendingEvents[id]?.event
        return unless scripts? and pendingEvent? and script in scripts
        if e.prevent is 'all'
          delete @_pendingEvents[id]
        else if e.prevent is 'none'
          removeFromArray scripts, script
          if scripts.length == 0
            delete @_pendingEvents[id]
            @emit pendingEvent.type, pendingEvent
        else
          console.warn 'received unknown propagation prevention type:', e.prevent

      when 'command', 'sevrer', 'message'
        # TODO add the script id to a blacklist so we don't go into a loop
        # TODO check args for correctness
        @_handleEvent e

  tearDown: ->
    removeEventListener 'message', @_handleEvent

exports.ScriptHandler = ScriptHandler