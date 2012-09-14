userInput = new UserInputHandler
scriptHandler = new window.script.ScriptHandler
chat = new window.chat.Chat

userInput.setContext chat

scriptHandler.intercept chat
userInput = scriptHandler.intercept(userInput)

chat.setUserInput userInput
chat.setScriptEvents scriptHandler
chat.interceptIRCEvents scriptHandler.intercept

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
