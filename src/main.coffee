userInput = new UserInputHandler $('#input'), $(window)
scriptHandler = new window.script.ScriptHandler
chat = new window.chat.Chat

userInput.setContext chat

scriptHandler.addEventsFrom chat
scriptHandler.addEventsFrom userInput
scriptHandler.listenToScriptEvents chat

chat.listenToCommands scriptHandler
chat.listenToScriptEvents scriptHandler
chat.listenToIRCEvents scriptHandler
chat.init()