exports = window.mocks ?= {}

class Runtime

  @useMock: ->
    chrome.runtime = new Runtime
    spyOn chrome.runtime, 'reload'

  constructor: ->
    @onUpdateAvailable = {}
    @onUpdateAvailable.addListener = @_addUpdateListener

  reload: ->

  _addUpdateListener: (callback) =>
    @updateAvailable = callback

exports.Runtime = Runtime