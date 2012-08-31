irc5 = new IRC5

$cmd = $('#cmd')
$cmd.focus()

$(window).keydown (e) ->
  unless e.metaKey or e.ctrlKey
    e.currentTarget = $('#cmd')[0]
    $cmd.focus()
  if e.altKey and 48 <= e.which <= 57
    irc5.command("/win " + (e.which - 48))
    e.preventDefault()

$cmd.keydown (e) ->
  if e.which == 13
    input = $cmd.val()
    if input.length > 0
      $cmd.val('')
      irc5.onTextInput input