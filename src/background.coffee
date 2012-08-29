chrome.app.runtime.onLaunched.addListener ->
  chrome.app.window.create 'bin/main.html'
