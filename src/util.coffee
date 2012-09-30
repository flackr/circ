exports = window

exports.assert = (cond) ->
  throw new Error("assertion failed") unless cond

exports.removeFromArray = (array, toRemove) ->
  for e, i in array
    if toRemove == e
      return array.splice i, 1
  return false

##
# Capitalises the given string.
# @param {string} sentence
# @return {string}
##
exports.capitaliseString = (sentence) ->
  sentence[0].toUpperCase() + sentence[1..]

##
# Returns whether or not the given string has non-whitespace characters.
# @param {string} phrase
# @return {boolean}
##
exports.stringHasContent = (phrase) ->
  return false unless phrase
  /\S/.test phrase