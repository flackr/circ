exports = window.chat ?= {}

class DeveloperCommands extends MessageHandler
  constructor: (@_commandHandler) ->
    super undefined
    @registerHandlers @_developerCommands

  _developerCommands:
    1: ->
      @_handleCommand "server", "irc.corp.google.com"

    2: ->
      @_handleCommand "nick", "sugarman#{Math.floor(Math.random() * 100)}"

    3: ->
      @_handleCommand "join", "#sugarman"

    4: ->
      @_handleCommand "say", "hello thar #{irc.util.randomName()}!"

    5: ->
      @_handleCommand "join", "#sugarman2"

    6: ->
      @_handleCommand "say", "Hey #{irc.util.randomName()}!"

    7: ->
      @_handleCommand "server", "irc.freenode.net"

    8: ->
      @_handleCommand "win", "0"
      @_handleCommand "join", "#sugarman"

    q: ->
      @_handleCommand "quit", "quitting a server"

    q1: ->
      @_handleCommand "win", "1"
      @_handleCommand "quit", "quitting a server in window 1"

    n: ->
      new chat.Notification('test', 'hi!').show()

    l: ->
      @_handleCommand "load", ""

  _handleCommand: (command, text) ->
    @_commandHandler.handle command, text.split(' ')...

exports.DeveloperCommands = DeveloperCommands