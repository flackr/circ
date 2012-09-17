window.parent.postMessage({type: 'onload'}, '*')

onMessage = (e) ->
  return unless e.data.type == 'source_code' and e.data.sourceCode?
  removeEventListener 'message', onMessage
  eval e.data.sourceCode
  return

addEventListener 'message', onMessage