exports = window.mocks ?= {}

class RemoteDevice extends EventEmitter
  @useMock: ->
    window.RemoteDevice = RemoteDevice

  @devices: []

  @reset: ->
    @devices = []

  constructor: (@id) ->
    super
    RemoteDevice.devices.push this

  @getOwnDevice: (callback) ->
    callback new RemoteDevice '1.1.1.1'

  send: ->

  listenForNewDevices: (callback) ->

  connect: (callback) ->
    callback true

  close: ->

exports.RemoteDevice = RemoteDevice