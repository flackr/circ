addEventListener 'message', (e) =>
  @onMessage(e.data) if typeof @onMessage is 'function'

@setName = (name) ->
  # TODO

@setDescription = (description) ->
  # TODO

@enableOptionsPage = ->
  # TODO

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
