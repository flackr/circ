chat = new window.chat.Chat

#scriptHandler = new window.script.ScriptHandler()
#scriptHandler.registerChatEvents chat
#chat.registerScriptEvents scriptHandler
#
#f = document.createElement('iframe')
#$(f).attr('src', 'script_frame.html')
#f.style.display = 'none'
#document.body.appendChild(f)
#
#addEventListener 'message', (e) ->
#  console.log 'got', e.data, 'from', e.origin
#  console.log 'is our frame?', e.source == f.contentWindow
#
#pm = ->
#  f.contentWindow.postMessage('to iframe', '*')
#  console.log 'posted message to frame'
#
#setTimeout(pm, 100)

$cmd = $('#cmd')
$cmd.focus()

$(window).keydown (e) ->
  unless e.metaKey or e.ctrlKey
    e.currentTarget = $('#cmd')[0]
    $cmd.focus()
  if e.altKey and 48 <= e.which <= 57
    chat.onTextInput "/win " + (e.which - 48)
    e.preventDefault()

$cmd.keydown (e) ->
  if e.which == 13
    input = $cmd.val()
    if input.length > 0
      $cmd.val('')
      chat.onTextInput input