exports = window.script ?= {}

class ScriptHandler extends EventEmitter
  constructor: ->
    @_frames = []
    @_registeredCommandMap = {}
    @_pendingCommandsMap = {}
    @_commandCount = 0
    @_emitterContext = {}
#    @_commands = new script.ScriptCommandHandler()
#    @_commands.setCallback @_onCommand
#    @_events = new script.ScriptEventHandler()
#    @_events.setCallback @_onEvent
    addEventListener 'message', @_handleMessage

  intercept: (emitter, opt_context) ->
    @_emitterContext[emitter] = opt_context
    emitter.on 'command', (sevrer, channel, command, args...) =>
      command = ['command', cmd, args...]
      id = @_comandCount++
      assert not (id of @_pendingCommandsMap)
      for frame in @_frames when @_registeredCommandMap[frame]?
        if cmd of @_registeredCommandMap[frame]
          frame.postMessage { type: 'command', context: {sevrer, channel}, command, args, id }, '*'
          @_pendingCommandsMap[id] ?= {}
          @_pendingCommandsMap[id].frames ?= []
          @_pendingCommandsMap[id].frames.push frame
          @_pendingCommandsMap[id].command ?= command
      if not id in @_pendingCommandsMap
        @emit command...

  setChatEvents: (emitter) ->
#    @_events.listenTo emitter

  addScriptFrame: (frame) ->
    @_frames.push frame

  _handleMessage: (e) =>
    return unless e.source in @_frames and e.data?.type
    switch e.data.type
      when 'hook_command'
        return unless e.data.command
        @_registeredCommandMap[e.source] ?= []
        @_registeredCommandMap.push e.data.command

      when 'propagation'
        id = e.data.id
        frames = @_pendingCommandsMap[id]
        if frames? and e.source in frames
          if e.data.prevent is 'all' or e.data.prevent is 'client'
            command = @_pendingCommandsMap[id].command
            delete @_pendingCommandsMap[id]
          if e.data.prevent is 'none' or 'plugin'
            @_pendingCommandsMap[id].remove e.source
            if @_pendingCommandsMap[id].length == 0
              @emit @_pendingCommandsMap[id].command
              delete @_pendingCommandsMap[id]
          else
            console.warn 'received unknown propagation prevention type:', e.data.prevent


#    type = e.data.type
#    if @_commands.canHandle type
#      @_commands.handle type, e.data

#  _onCommand: (commandArgs...) =>
#    @emit commandArgs...

#  _onEvent: (eventObj) =>
#    # TODO determine which frames should receive the eventObj

  tearDown: ->
    removeEventListener 'message', @_handleEvent


exports.ScriptHandler = ScriptHandler