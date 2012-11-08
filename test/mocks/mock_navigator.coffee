exports = window.mocks ?= {}

class Navigator

  useMock: ->
    window.navigator = exports.navigator
    @goOnline()

  goOnline: ->
    @onLine = true

  goOffline: ->
    @onLine = false

  onLine: true

exports.navigator = new Navigator