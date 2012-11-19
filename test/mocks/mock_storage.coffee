exports = window.mocks ?= {}

class Storage

  @useMock: ->
    (window.chrome ?= {}).storage ?= {}
    window.chrome.storage.sync = new Storage
    window.chrome.storage.local = new Storage
    window.chrome.storage.onChanged =
      addListener: (update) ->
        window.chrome.storage.update = update

  constructor: () ->
    @_storageMap = {}

  set: (obj) ->
    (@_storageMap[k] = v for k, v of obj)

  get: (keys, callback) ->
    if typeof keys is 'string'
      return @get [keys], callback
    result = {}
    (result[k] = v for k, v of @_storageMap)
    callback result

  clear: ->
    @_storageMap = {}

exports.storage = Storage