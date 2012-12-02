exports = window

# determine API support
exports.api =
  listenSupported: ->
    chrome.socket?.listen and chrome.experimental

  acceptSupported: ->
    chrome.socket?.accept and chrome.experimental

  socketSupported: ->
    chrome.socket

  getNetworkListSupported: ->
    chrome.socket?.getNetworkList

##
# Returns a human readable representation of a list.
# For example, [1, 2, 3] becomes "1, 2 and 3".
# @param {Array.<Object>} array
# @return {string}
##
exports.getReadableList = (array) ->
  if array.length is 1
    array[0].toString()
  else
    allButLastElement = array[..array.length-2]
    allButLastElement.join(', ') + ' and ' + array[array.length-1]

exports.getReadableTime = (milliseconds) ->
  date = new Date()
  date.setMilliseconds(milliseconds)
  date.toString()

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

exports.pluralize = (word, number) ->
  return word if not word or number is 1
  if word[word.length-1] is 's'
    word + 'es'
  else
    word + 's'

exports.truncateIfTooLarge = (text, maxSize, suffix='...') ->
  if text.length > maxSize
    text[..maxSize - suffix.length - 1] + suffix
  else
    text

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

exports.html = {}

exports.html.escape = (html) ->
  escaped = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
  }
  String(html).replace /[&<>"]/g, (character) -> escaped[character] ? character

##
# Escapes HTML and linkifies
##
exports.html.display = (text) ->
  escapeHTML = exports.html.escape
  # Gruber's url-finding regex
  rurl = /\b((?:[a-z][\w-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))/gi
  canonicalise = (url) ->
    url = escapeHTML url
    if url.match(/^[a-z][\w-]+:/i)
      url
    else
      'http://' + url

  escape = (str) ->
    # long words need to be extracted before escaping so escape HTML characters
    # don't scew the word length
    longWords = str.match(/\S{40,}/g) ? []
    longWords = (escapeHTML(word) for word in longWords)
    str = escapeHTML(str)
    result = ''
    for word in longWords
      replacement = "<span class=\"longword\">#{word}</span>"
      str = str.replace word, replacement
      result += str[.. str.indexOf(replacement) + replacement.length - 1]
      str = str[str.indexOf(replacement) + replacement.length..]
    result + str

  res = ''
  textIndex = 0
  while m = rurl.exec text
    res += escape(text.substr(textIndex, m.index - textIndex))
    res += '<a target="_blank" href="'+canonicalise(m[0])+'">'+escape(m[0])+'</a>'
    textIndex = m.index + m[0].length
  res += escape(text.substr(textIndex))
  return res
