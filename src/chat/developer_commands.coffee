exports = window.chat ?= {}

##
# Special commands used to make testing easier. These commands are not
# displayed in /help.
##
class DeveloperCommands extends MessageHandler
  constructor: (@_chat) ->
    super

  _handlers:
    'test-notif': ->
      new chat.Notification('test', 'hi!').show()

    'get-pw': ->
      @_chat.displayMessage 'notice', @params[0].context, 'Your password is: ' +
          @_chat.remoteConnection._password

    'set-pw': (event) ->
      password = event.args[0] ? 'bacon'
      @_chat.storage._store 'password', password
      @_chat.setPassword password

  _handleCommand: (command, text='') ->
    @_chat.userCommands.handle command, @params[0], text.split(' ')...

exports.DeveloperCommands = DeveloperCommands