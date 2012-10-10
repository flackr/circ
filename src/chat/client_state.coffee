exports = window.chat ?= {}

class ClientState

  constructor: (chat) ->
    @_chat = chat

exports.ClientState = ClientState