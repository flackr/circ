chrome.app.runtime.onLaunched.addListener ->
  chrome.app.window.create 'bin/main.html',
    width: 775
    height: 400
    minWidth: 570
    minHeight: 160
