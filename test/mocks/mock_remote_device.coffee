exports = window.mocks ?= {}

class RemoteDevice
  @useMock: ->
    window.RemoteDevice = RemoteDevice

  constructor: (connectionId) ->
    if typeof connectionId is 'string'
      @_addr = connectionId
    else
      @_socketId = connectionId
    @id = connectionId

  @getOwnDevice: (callback) ->
    callback new RemoteDevice '127.0.0.1'

  listenForNewDevices: (callback) ->

  _acceptNewConnection: (addr, port, callback) ->

  _send: (type, args) ->

  connect: ->

  close: ->

  _setSocketId: ->

  _listenForData: ->

exports.RemoteDevice = RemoteDevice