exports = window

class Util
  assert: (cond) ->
    throw new Error("assertion failed") unless cond

  removeFromArray: (array, toRemove) ->
    for e, i in array
      if toRemove == e
        return array.splice i, 1
    return false

exports.util = new Util