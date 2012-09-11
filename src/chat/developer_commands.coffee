exports = window.chat ?= {}

class DeveloperCommands extends MessageHandler
  constructor: (source) ->
    super source
    @registerHandlers @_developerCommands

  _developerCommands:
    1: ->
      @onTextInput "/server irc.corp.google.com"

    2: ->
      @onTextInput "/nick sugarman#{Math.floor(Math.random() * 100)}"

    3: ->
      @onTextInput "/join #sugarman"

    4: ->
      @onTextInput "hello thar #{irc.util.randomName()}!"

    5: ->
      @onTextInput "/join #sugarman2"

    6: ->
      @onTextInput "/say Hey #{irc.util.randomName()}!"

    7: ->
      @onTextInput "/server irc.freenode.net"

    8: ->
      @onTextInput "/win 0"
      @onTextInput "/join #sugarman"

    q: ->
      @onTextInput "/quit quitting a server"

    q1: ->
      @onTextInput "/win 1"
      @onTextInput "/quit quitting a sever in window 1"

    n: ->
      new chat.Notification('test', 'hi!').show()

exports.DeveloperCommands = DeveloperCommands