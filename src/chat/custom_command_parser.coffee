exports = window.chat ?= {}

##
# Parses raw commands from the user. Used with the /raw command.
##
class CustomCommandParser

  parse: (channel, args...) ->
    if args[1] == '-c'
      params = @_mergeQuotedWords args[2..]
      [args[0].toUpperCase(), channel, params...]
    else
      params = @_mergeQuotedWords args[1..]
      [args[0].toUpperCase(), params...]

  _mergeQuotedWords: (words) ->
    start = -1
    for word, i in words
      if word[0] == '"' and start == -1
        start = i
      if word[word.length-1] == '"' and start != -1
        words.splice start, i - start + 1, words[start..i].join ' '
        words[start] = @_trimQuotes words[start]
        return @_mergeQuotedWords words
    words

  _trimQuotes: (word) ->
    word[1..word.length-2]

exports.customCommandParser = new CustomCommandParser()