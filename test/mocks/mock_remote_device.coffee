exports = window.mocks ?= {}

class RemoteDevice extends EventEmitter
  @useMock: ->
    window.RemoteDevice = RemoteDevice
    (window.chrome ?= {}).socket =
      create: ->
      listen: ->

  @state: 'finding_addr'

  @devices: []

  @reset: ->
    @devices = []

  @sendAuthentication: ->

  getState: ->
    RemoteDevice.state

  constructor: (@id) ->
    super
    @addr = @id
    RemoteDevice.devices.push this

  @getOwnDevice: (callback) ->
    callback new RemoteDevice '1.1.1.1'

  send: ->

  listenForNewDevices: (callback) ->
    RemoteDevice.onNewDevice = callback

  connect: (callback) ->
    callback true

  sendAuthentication: (getAuthToken) ->
    RemoteDevice.sendAuthentication getAuthToken '1.1.1.1'

  getAddr: (callback) ->
    @addr = '1.1.1.1'
    callback '1.1.1.1'

  close: ->

exports.RemoteDevice = RemoteDevice