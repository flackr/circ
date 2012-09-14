exports = window.script ?= {}

class ScriptHandler extends EventEmitter
  constructor: ->
    super
    @_frames = {}
    @_frameCount = 0
    @_hookedCommandMap = {}
    @_pendingCommandsMap = {}
    @_commandCount = 0
    @_emitterContext = {}
#    @_commands = new script.ScriptCommandHandler()
#    @_commands.setCallback @_onCommand
#    @_events = new script.ScriptEventHandler()
#    @_events.setCallback @_onEvent
    @_emitters = []
    @_hookedEvents = [ 'command' ]
    addEventListener 'message', @_handleMessage

  on: (ev, cb) ->
    if not (ev in @_hookedEvents)
      @_forwardEvent ev, cb
    else
      super ev, cb

  _forwardEvent: (ev, cb) ->
    for emitter in @_emitters
      emitter.on ev, cb

  intercept: (emitter, opt_context) =>
    @_emitters.push emitter
    @_emitterContext[emitter] = opt_context
    emitter.on 'command', @_handleCommand
    this

  _handleCommand: (server, channel, command, args...) =>
    emitCommand = ['command', arguments...]
    id = @_commandCount++
    assert not (id of @_pendingCommandsMap)
    for fid, frame of @_frames when @_hookedCommandMap[fid]?
      if command in @_hookedCommandMap[fid]
        frame.postMessage { type: 'command', context: {server, channel}, command, args, id }, '*'
        @_pendingCommandsMap[id] ?= {}
        @_pendingCommandsMap[id].frames ?= []
        @_pendingCommandsMap[id].frames.push frame
        @_pendingCommandsMap[id].command ?= emitCommand
    if not (id of @_pendingCommandsMap)
      @emit emitCommand...

  addScriptFrame: (frame) ->
    id = @_frameCount++
    @_frames[id] = frame
    frame.id = id

  _getIDForFrame: (frame) ->
    for id, f of @_frames
      return id if f == frame
    return undefined

  _removeElement: (array, toRemove) =>
    for e, i in array
      if toRemove == e
        array.splice i, 1
        return

  _handleMessage: (e) =>
    frameID = @_getIDForFrame e.source
    return unless frameID? and e.data?.type
    switch e.data.type
      when 'hook_command'
        return unless e.data.command
        @_hookedCommandMap[frameID] ?= []
        @_hookedCommandMap[frameID].push e.data.command

      when 'propagation'
        id = e.data.id
        frames = @_pendingCommandsMap[id]?.frames
        command = @_pendingCommandsMap[id]?.command
        return unless frames? and command? and e.source in frames
        if e.data.prevent is 'all'
          delete @_pendingCommandsMap[id]
        else if e.data.prevent is 'none'
          @_removeElement frames, e.source
          if frames.length == 0
            delete @_pendingCommandsMap[id]
            @emit command
        else
          console.warn 'received unknown propagation prevention type:', e.data.prevent

      when 'command'
        # TODO add the frameid to a blacklist so we don't go into a loop
        # TODO check args for correctness
        d = e.data
        @_handleCommand d.context.server, d.context.channel, d.command, d.args...

  tearDown: ->
    removeEventListener 'message', @_handleEvent

exports.ScriptHandler = ScriptHandler