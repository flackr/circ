exports = window.script ?= {}

##
# Handles currently running scripts.
##
class ScriptHandler extends EventEmitter

  # A set of events that cannot be intercepted by scripts.
  @UNINTERCEPTABLE_EVENTS = { 'command help', 'command about' }

  constructor: ->
    super
    @_scripts = {}
    @_pendingEvents = {}
    @_eventCount = 0
    @_emitters = []
    @_hookableEvents = [ 'command', 'server', 'message' ]
    addEventListener 'message', @_handleMessage
    @_loadPrepackagedScripts()

  _loadPrepackagedScripts: ->
    window.script.loader.loadPrepackagedScripts (script) =>
      @addScript script

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

  removeEventsFrom: (emitter) ->
    @_emitters.splice @_emitters.indexOf(emitter), 1
    for event in @_hookableEvents
      emitter.removeListener event, @_handleEvent

  _handleEvent: (event) =>
    event.id = @_eventCount++
    @_forwardEventToScripts event if @_eventCanBeForwarded event
    unless @_eventIsBeingHandled event.id
      @_emitEvent event

  ##
  # Certain events are not allowed to be intercepted by scripts for security reasons.
  # @param {Event} event
  # @return {boolean} Returns true if the event can be forwarded to scripts.
  ##
  _eventCanBeForwarded: (event) ->
    return not (event.hook of ScriptHandler.UNINTERCEPTABLE_EVENTS)

  _forwardEventToScripts: (event) ->
    for scriptId, script of @_scripts
      if script.shouldHandle event
        @_sendEventToScript event, script

  _sendEventToScript: (event, script) ->
    script.postMessage event
    @_markEventAsPending event, script

  _markEventAsPending: (event, script) ->
    unless @_pendingEvents[event.id]
      @_pendingEvents[event.id] = {}
      @_pendingEvents[event.id].event = event
      @_pendingEvents[event.id].scripts = []
    @_pendingEvents[event.id].scripts.push script

  _eventIsBeingHandled: (eventId) ->
    return false unless eventId of @_pendingEvents
    @_pendingEvents[eventId].scripts.length > 0

  _handleMessage: (message) =>
    event = message.data
    script = window.script.Script.getScriptFromFrame @_scripts, message.source
    return unless script?
    switch event.type
      when 'hook_command', 'hook_server', 'hook_message'
        type = event.type[5..] # remove 'hook_' prefix
        script.beginHandlingType type, event.name

      when 'propagate'
        @_handleEventPropagation script, event

      when 'command', 'sevrer', 'message'
        # TODO add the script id to a blacklist so we don't go into a loop
        # TODO check args for correctness
        @_handleEvent Event.wrap event

  _handleEventPropagation: (script, propagatationEvent) ->
    eventId = propagatationEvent.args?[0]
    return unless @_eventIsBeingHandled eventId

    scriptsHandlingEvent = @_pendingEvents[eventId].scripts
    return unless script in scriptsHandlingEvent

    switch propagatationEvent.name
      when 'none'
        delete @_pendingEvents[eventId]
      when 'all'
        @_stopHandlingEvent script, eventId
        unless @_eventIsBeingHandled eventId
          event = @_pendingEvents[eventId].event
          delete @_pendingEvents[eventId]
          @_emitEvent event
      else
        @_log 'w', 'received unknown propagation type:', propagatationEvent.name

  _emitEvent: (event) ->
    @emit event.type, event

  _stopHandlingEvent: (script, eventId) ->
    scriptsHandlingEvent = @_pendingEvents[eventId].scripts
    removeFromArray scriptsHandlingEvent, script

  tearDown: ->
    removeEventListener 'message', @_handleEvent

exports.ScriptHandler = ScriptHandler