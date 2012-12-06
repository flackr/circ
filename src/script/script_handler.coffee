exports = window.script ?= {}

##
# Handles currently running scripts. Events sent from the user and IRC servers
# are intercepted by this class, passed to scripts, and then forwarded on to
# their destination.
##
class ScriptHandler extends EventEmitter

  # Script names that are longer this this are truncated.
  @MAX_NAME_LENGTH = 20

  # A set of events that cannot be intercepted by scripts.
  @UNINTERCEPTABLE_EVENTS = { 'command help', 'command about',
      'command install', 'command uninstall', 'command scripts' }

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

  ##
  # Add a script to the list of currently active scripts. Once added, the script
  # will receive events from the user and IRC server.
  # @param {Script} script
  ##
  addScript: (script) ->
    @_scripts[script.id] = script

  ##
  # Remove a script to the list of currently active scripts. Once removed, the
  # script will not longer receive events from the user or IRC server.
  # @param {Script} script
  ##
  removeScript: (script) ->
    for eventId in @_getPendingEventsForScript script
      @_stopHandlingEvent script, eventId
    delete @_scripts[script.id]

  _getPendingEventsForScript: (script) ->
    pendingEventIds = []
    for id, pendingEventInfo of @_pendingEvents
      for scriptWithPendingEvent in pendingEventInfo.scripts
        pendingEventIds.push id if scriptWithPendingEvent.id is script.id
    pendingEventIds

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

      when 'command', 'sevrer', 'message'
        # TODO add the script id to a blacklist so we don't go into a loop
        # TODO check args for correctness
        @_handleEvent Event.wrap event

      when 'propagate'
        @_handleEventPropagation script, event

      when 'meta'
        @_handleMetaData script, event

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
      else
        @_log 'w', 'received unknown propagation type:', propagatationEvent.name

  ##
  # Handles a meta data event, such as setting the script name.
  ##
  _handleMetaData: (script, event) ->
    switch event.name
      when 'name'
        name = event.args[0]
        return unless @_isValidName name
        uniqueName = @_getUniqueName name
        script.setName uniqueName

  ##
  # Returns true if the given script name contains only valid characters.
  # @param {string} name The script name.
  # @return {boolean}
  ##
  _isValidName: (name) ->
    name and /^[a-zA-Z0-9/]+$/.test name

  ##
  # Appends numbers to the end of the script name until it is unique.
  # @param {string} name
  ##
  _getUniqueName: (name) ->
    originalName = name = name[..ScriptHandler.MAX_NAME_LENGTH-1]
    suffix = 1
    while name in @getScriptNames()
      suffix++
      name = originalName + suffix
    return name

  getScriptNames: ->
    (script.getName() for id, script of @_scripts)

  getScriptByName: (name) ->
    for id, script of @_scripts
      return script if script.getName() is name
    return null

  _emitEvent: (event) ->
    @emit event.type, event

  _stopHandlingEvent: (script, eventId) ->
    scriptsHandlingEvent = @_pendingEvents[eventId].scripts
    removeFromArray scriptsHandlingEvent, script
    unless @_eventIsBeingHandled eventId
      event = @_pendingEvents[eventId].event
      delete @_pendingEvents[eventId]
      @_emitEvent event

  tearDown: ->
    removeEventListener 'message', @_handleEvent

exports.ScriptHandler = ScriptHandler