exports = window.chat ?= {}

class NickMentionedNotification extends window.chat.Notification
  constructor: (from, msg) ->
    super "#{from} mentioned you", msg

  @shouldNotify: (nick, msg) ->
    # TODO actual impl untested, so returning false for now
    return false
    return false if not nick?
    testMsg = @_removeNicksThatFailLookBehind msg, nick
    nickRegex = new RegExp @_escapeRegEx "@?sugarman_*[!?.]*[,:~\*]?(?!^\s)"
    nickRegex.test testMsg

  @_removeNicksThatFailLookBehind: (msg, nick) ->
    msg = msg.toLowerCase()
    return msg.replace("\\S#{nick}", 'a')

  @_escapeRegEx: (text) ->
    text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&")

