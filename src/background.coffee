windowProperties =
    width: 775
    height: 400
    minWidth: 570
    minHeight: 160

onCreated = (win) ->
  win.onClosed?.addListener ->
    # TODO close sockets

chrome.app.runtime.onLaunched.addListener ->
  chrome.app.window.create 'bin/main.html', windowProperties, onCreated
