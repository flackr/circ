exports = window.script ?= {}

class ScriptHandler extends EventEmitter
  constructor: ->
    super
    @_scripts = {}
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
    for sid, script of @_scripts when command in script.hookedCommands
      script.postMessage { type: 'command', context: {server, channel}, command, args, id }
      @_pendingCommandsMap[id] ?= {}
      @_pendingCommandsMap[id].scripts ?= []
      @_pendingCommandsMap[id].scripts.push script
      @_pendingCommandsMap[id].command ?= emitCommand
    if not (id of @_pendingCommandsMap)
      @emit emitCommand...

  addScript: (script) ->
    @_scripts[script.id] = script

  _handleMessage: (e) =>
    script = window.script.Script.getScriptFromFrame e.source
    return unless script? and e.data?.type
    switch e.data.type
      when 'hook_command'
        return unless e.data.command
        script.hookedCommands.push e.data.command

      when 'propagation'
        id = e.data.id
        scripts = @_pendingCommandsMap[id]?.scripts
        command = @_pendingCommandsMap[id]?.command
        return unless scripts? and command? and e.source in scripts
        if e.data.prevent is 'all'
          delete @_pendingCommandsMap[id]
        else if e.data.prevent is 'none'
          util.removeFromArray scripts, e.source
          if scripts.length == 0
            delete @_pendingCommandsMap[id]
            @emit command
        else
          console.warn 'received unknown propagation prevention type:', e.data.prevent

      when 'command'
        # TODO add the script id to a blacklist so we don't go into a loop
        # TODO check args for correctness
        d = e.data
        @_handleCommand d.context.server, d.context.channel, d.command, d.args...

  tearDown: ->
    removeEventListener 'message', @_handleEvent

exports.ScriptHandler = ScriptHandler