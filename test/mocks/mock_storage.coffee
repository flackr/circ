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
    keys = [keys] if typeof keys is 'string'
    result = {}
    for k, v of @_storageMap
      result[k] = v if k in keys
    callback result

  remove: (keys) ->
    keys = [keys] if typeof keys is 'string'
    for k in keys
      delete @_storageMap[k]

  clear: ->
    @_storageMap = {}

exports.storage = Storage