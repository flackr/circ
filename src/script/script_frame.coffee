window.parent.postMessage({type: 'onload'}, '*')

onMessage = (e) ->
  return if e.data.type != 'script' or not e.data.script?
  removeEventListener 'message', onMessage
  eval e.data.script
  return

addEventListener 'message', onMessage