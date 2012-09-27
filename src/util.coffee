exports = window

exports.assert = (cond) ->
  throw new Error("assertion failed") unless cond

exports.removeFromArray = (array, toRemove) ->
  for e, i in array
    if toRemove == e
      return array.splice i, 1
  return false

exports.capitalise = (sentence) ->
  sentence[0].toUpperCase() + sentence[1..]