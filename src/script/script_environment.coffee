window.parent.postMessage({type: 'onload'}, '*')

onInitMessage = (e) ->
  return unless e.data.type == 'source_code' and e.data.sourceCode?
  removeEventListener 'message', onInitMessage
  initEnvironment()
  eval e.data.sourceCode
  return

addEventListener 'message', onInitMessage

initEnvironment = ->
  addEventListener 'message', (e) =>
    @onMessage(e.data) if typeof @onMessage is 'function'

  @send = (opt_context, type, name, args...) ->
    if typeof opt_context is 'string' # no context
      args = [name].concat(args)
      name = type
      type = opt_context
      opt_context = {}
    event = {opt_context, type, name, args}
    window.parent.postMessage(event, '*')

  @propagate = (event, propagation='all') ->
    @send event.context, 'propagate', propagation, event.id


