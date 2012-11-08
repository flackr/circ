exports = window.mocks ?= {}

class Navigator

  useMock: ->
    window.navigator = exports.navigator
    @onLine = true

  goOnline: ->
    wasOffline = not @onLine
    @onLine = true
    $(window).trigger 'online' if wasOffline

  goOffline: ->
    wasOnline = @onLine
    @onLine = false
    $(window).trigger 'offline' if wasOnline

  onLine: true

exports.navigator = new Navigator