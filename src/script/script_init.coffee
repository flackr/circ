window.parent.postMessage({type: 'onload'}, '*')

onInitMessage = (e) ->
  return unless e.data.type == 'source_code' and e.data.sourceCode?
  removeEventListener 'message', onInitMessage
  eval e.data.sourceCode
  return

addEventListener 'message', onInitMessage
