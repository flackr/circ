exports = window.test ?= {}

class MockMessageHandler extends MessageHandler
  constructor: (source) ->
    super source
    @registerHandlers @_messages

  _messages:
    eat: ->

    drink: ->

exports.MockMessageHandler = MockMessageHandler