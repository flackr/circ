windowProperties =
  width: 775
  height: 400
  minWidth: 570
  minHeight: 160

currentApp = null

appIsRunning = ->
  not currentApp?.contentWindow.closed

onCreated = (win) ->
  currentApp = win
  win.onClosed?.addListener ->
    window.close()

create = ->
  chrome.app.window.create 'bin/main.html', windowProperties, onCreated

chrome.runtime.onStartup?.addListener ->
  chrome.storage.sync.get 'autostart', (storageMap) ->
    if storageMap.autostart
      create()

chrome.app.runtime.onLaunched?.addListener ->
  if appIsRunning()
    currentApp.focus()
  else
    create()

##
# Repeatedly check if the window has been closed and close the background page
# when it has.
# TODO: Take this out once the onClose event hits stable.
##
closeWhenAppCloses = ->
  setInterval =>
    unless appIsRunning()
      window.close()
  , 1000

chrome.runtime.onUpdateAvailable?.addListener =>
  return unless chrome.runtime.reload?
  if appIsRunning()
    closeWhenAppCloses()
  else
    window.close()