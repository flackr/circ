window.parent.postMessage({type: 'onload'}, '*')

onInitMessage = (e) ->
  console.log 'script got init message'
  return unless e.data.type == 'source_code' and e.data.sourceCode?
  removeEventListener 'message', onInitMessage
  eval e.data.sourceCode
  return

console.log 'adding onInitMessage listener'
addEventListener 'message', onInitMessage

console.log('welcome - ScriptInit');
if this.setName then console.log('has set name')
if (this.setDescription) then console.log('has set des')
if (this.enableOptions) then console.log('has en op')
if (this.send) then console.log('has send')