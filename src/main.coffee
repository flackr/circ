userInput = new UserInputHandler

scriptHandler = new ScriptHandler
userInput = scriptHandler.intercept(userInput)

chat = new window.chat.Chat
chat.setUserInput userInput
chat.setScriptEvents scriptHandler
chat.interceptIRCEvents scriptHandler.intercept

userInput.setContext chat
scriptHandler.setChatEvents chat

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
