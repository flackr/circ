windowProperties =
  width: 775
  height: 400
  minWidth: 570
  minHeight: 160

currentApp = null

##
# TODO: This is a hack to determine if the app is running - we can remove this
# once the onClose event hits stable.
##
appIsRunning = ->
  return currentApp?.contentWindow.navigator

onCreated = (win) ->
  currentApp = win
  win.onClosed?.addListener ->
    # TODO: close sockets, reload if an update is available

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
# Repeatedly check if the window has been closed and update when it has.
# TODO: This won't be needed once the onClose event hits stable.
##
updateWhenAppCloses = ->
  setInterval =>
    unless appIsRunning()
      chrome.runtime.reload()
  , 1000

chrome.runtime.onUpdateAvailable?.addListener =>
  return unless chrome.runtime.reload?
  if appIsRunning()
    updateWhenAppCloses()
  else
    chrome.runtime.reload()