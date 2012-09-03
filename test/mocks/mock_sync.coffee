exports = (window.chrome ?= {}).storage ?= {}

class Sync
  constructor: ->
    @_storageMap =
      nick:
        'sugarman'

  set: (obj) ->
    (@_storageMap[k] = v for k, v of obj)

  get: (key, callback) ->
    callback @_storageMap

exports.sync = new Sync