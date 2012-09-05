exports = window.chat ?= {}

class NickMentionedNotification extends window.chat.Notification
  constructor: (from, msg) ->
    super "#{from} mentioned you", msg

  @shouldNotify: (nick, msg) ->
    return false if not nick?
    # TODO have optional underscores if it doesn't conflict with another name
    msgToTest = @_prepMessageForRegex msg, nick
    ///
      \#nick\#     # the nickname
      ([!?.]* |    # any number of ! ? .
      [-:;~\*]?)  # or one ending punctuation
      (?!\S)       # can't be followed by a letter
    ///i.test msgToTest

  # do negative lookbehind and replace nick with a placeholder
  @_prepMessageForRegex: (msg, nick) ->
    msg = msg.replace(/,/g, ' ') # treat commas as whitespace
    msg = msg.replace(/\#nick\#/gi, 'a')
    msg = msg.replace(new RegExp("@\?#{nick}", "ig"), '#nick#') # optional preceding @
    # simulate a negative lookbehind to make sure only whitespace precedes the nick
    return msg.replace(/\S\#nick\#/i, 'a')

exports.NickMentionedNotification = NickMentionedNotification