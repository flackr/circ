exports = (window.chrome ?= {}).storage ?= {}

class Sync
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

exports.onChanged =
  addListener: (update) ->
    exports.update = update

exports.sync = new Sync