exports = window.mocks ?= {}

class RemoteDevice extends EventEmitter
  @useMock: ->
    window.RemoteDevice = RemoteDevice
    (window.chrome ?= {}).socket =
      create: ->
      listen: ->

    @state = 'finding_port'
    @willConnect = true
    @devices = []

  @sendAuthentication: ->

  @onConnect: (callback) ->
    callback RemoteDevice.willConnect

  equals: (o) ->
    o?.id is @id

  getState: ->
    RemoteDevice.state

  constructor: (@addr, @port) ->
    super
    @id = @addr ? RemoteDevice.devices.length
    RemoteDevice.devices.push this

  @getOwnDevice: (callback) ->
    device = new RemoteDevice '1.1.1.1'
    device.possibleAddrs = ['1.1.1.1']
    callback device

  send: ->

  listenForNewDevices: (callback) ->
    RemoteDevice.onNewDevice = callback

  connect: (callback) ->
    RemoteDevice.onConnect callback

  sendAuthentication: (getAuthToken) ->
    RemoteDevice.sendAuthentication getAuthToken '1.1.1.1'

  getAddr: (callback) ->
    @addr = '1.1.1.' + (RemoteDevice.devices.length + 1)
    callback @addr

  close: ->

exports.RemoteDevice = RemoteDevice