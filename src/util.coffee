exports = window

exports.isOnline = ->
  window.navigator.onLine

exports.assert = (cond) ->
  throw new Error("assertion failed") unless cond

exports.removeFromArray = (array, toRemove) ->
  i = array.indexOf toRemove
  return false if i < 0
  return array.splice i, 1

getLoggerForType = (type) ->
  switch type
    when 'w' then (msg...) => console.warn msg...
    when 'e' then (msg...) => console.error msg...
    else (msg...) => console.log msg...

exports.getLogger = (caller) ->
  (opt_type, msg...) ->
    if opt_type in ['l', 'w', 'e']
      type = opt_type
    else
      msg = [opt_type].concat msg
    getLoggerForType(type) "#{caller.constructor.name}:", msg...

##
# Capitalizes the given string.
# @param {string} sentence
# @return {string}
##
exports.capitalizeString = (sentence) ->
  return sentence unless sentence
  sentence[0].toUpperCase() + sentence[1..]

##
# Returns whether or not the given string has non-whitespace characters.
# @param {string} phrase
# @return {boolean}
##
exports.stringHasContent = (phrase) ->
  return false unless phrase
  /\S/.test phrase