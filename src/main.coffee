userInput = new UserInputHandler $('#cmd'), $(window)
scriptHandler = new window.script.ScriptHandler
chat = new window.chat.Chat

userInput.setContext chat

scriptHandler.addEventsFrom chat
scriptHandler.addEventsFrom userInput
scriptHandler.listenToScriptEvents chat

chat.listenToUserInput scriptHandler
chat.listenToScriptEvents scriptHandler
chat.listenToIRCEvents scriptHandler
