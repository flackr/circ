windowProperties =
    width: 775
    height: 400
    minWidth: 570
    minHeight: 160

prevWin = null

# TODO This is a hack to determine if the previous window has be closed.
previousWindowExists = ->
  return false unless prevWin
  try
    prevWin.focus() # will fail if the window has been closed
    return true
  return false

onCreated = (win) ->
  prevWin = win
  console.warn "CREATED WINDOW"
  win.onClosed?.addListener ->
    # TODO close sockets

create = ->
  chrome.app.window.create 'bin/main.html', windowProperties, onCreated

chrome.runtime.onStartup.addListener ->
  chrome.storage.sync.get 'autostart', (storageMap) ->
    if storageMap.autostart
      create()

chrome.app.runtime.onLaunched.addListener ->
  if previousWindowExists()
    prevWin.focus()
  else
    create()