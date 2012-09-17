userInput = new UserInputHandler
scriptHandler = new window.script.ScriptHandler
chat = new window.chat.Chat

userInput.setContext chat

scriptHandler.intercept chat
userInput = scriptHandler.intercept(userInput)

chat.setUserInput userInput
chat.setScriptEvents scriptHandler
chat.interceptIRCEvents scriptHandler.intercept
