exports = window.chat ?= {}

##
# Handles formatting and styling text to be displayed to the user.
#
# Formatting follows these ruels:
# - all messages start with a capital letter
# - messages from the user or to the user have the 'self' style
# - messages from the user are surrounded by parentheses
# - the user's nick is replaced by 'you'
# - 'you is' is replaced by 'you are'
# - messages not from the user end in a period
##
class MessageFormatter
  constructor: ->
    @_customStyle = []
    @_nick = undefined
    @clear()

  ##
  # Sets the user's nick name, which is used to determine if the message is from
  # or to the user. This field is not reset when clear() is called.
  # @param {string} nick The user's nick name.
  ##
  setNick: (nick) ->
    @_nick = nick

  ##
  # Sets custom style to be used for all formatted messages. This field is not
  # reset when clear() is called.
  # @param {Array.<string>} customStyle The style to be set
  ##
  setCustomStyle: (customStyle) ->
    @_customStyle = customStyle

  ##
  # Clears the state of the message formatter. Used between formatting different
  # messages.
  ##
  clear: ->
    @_style = []
    @_fromUs = @_toUs = false
    @_forcePrettyFormat = undefined
    @_message = ''

  ##
  # Sets the message to be formatted.
  # The following can be used as special literals in the message:
  # - '#from' gets replaced by the the nick the message is from.
  # - '#to' gets replaced by the nick the message pertains to.
  # - '#content' gets replaced by content the message is about.
  # @param {string} message
  ##
  setMessage: (message) ->
    @_message = message

  ##
  # Returns true if the formatter has a message to format.
  # @return {boolean}
  ##
  hasMessage: ->
    return !!@_message

  ##
  # Set the context of the message.
  # @param {string=} opt_from The nick the message is from.
  # @param {string=} opt_to The nick the message pertains to.
  # @param {string=} opt_content The context of the message.
  ##
  setContext: (opt_from, opt_to, opt_content) ->
    @_from = opt_from
    @_to = opt_to
    @_content = opt_content
    @_fromUs = @_isOwnNick @_from
    @_toUs = @_isOwnNick @_to

  ##
  # Set the content of the message.
  # @param {string} content
  ##
  setContent: (content) ->
    @_content = content

  ##
  # Sets the content to the given string and the message to be that content.
  # @param {string} content
  ##
  setContentMessage: (content) ->
    @setContext undefined, undefined, content
    @setContent content
    @setMessage '#content'

  ##
  # Set whether the message is from the user or not.
  # By default the message is assumed from the user if their nick matches the
  # from field.
  # This is useful for the /nick message, when the user's nick has just changed.
  # @param {boolean} formUs True if the message is from the user
  ##
  setFromUs: (fromUs) ->
    @_fromUs = fromUs

  ##
  # Set whether the message pertains to the user or not.
  # By default the message is assumed to pertain to the user if their nick
  # matches the to field.
  # This is useful for the /nick message, when the user's nick has just changed.
  # @param {boolean} toUs True if the message is to the user
  ##
  setToUs: (toUs) ->
    @_toUs = toUs

  ##
  # Sets whether or not pretty formatting should be used.
  # Pretty formatting includes capitalization and adding a period or adding
  # perentheses.
  ##
  setPrettyFormat: (usePrettyFormat) ->
    @_forcePrettyFormat = usePrettyFormat

  _usePrettyFormat: ->
    @_forcePrettyFormat ? not @hasStyle 'no-pretty-format'

  ##
  # Returns a message formatted based on the given context.
  # @return {string} Returns the formatted message.
  ##
  format: ->
    return '' unless @_message
    msg = @_incorporateContext()
    msg = @_prettyFormat msg if @_usePrettyFormat()
    return msg

  ##
  # Replaces context placeholders, such as '#to', with their corresponding
  # value.
  # @return {string} Returns the formatted message.
  ##
  _incorporateContext: ->
    msg = @_message
    msg = @_youIsToYouAre '#from', msg if @_fromUs
    msg = @_youIsToYouAre '#to', msg if @_toUs
    msg = msg.replace '#from', if @_fromUs then 'you' else @_from
    msg = msg.replace '#to', if @_toUs then 'you' else @_to
    msg.replace '#content', @_content

  ##
  # Handles adding periods, perentheses and capitalization.
  # @return {string} Returns the formatted message.
  ##
  _prettyFormat: (msg) ->
    msg = capitalizeString msg unless @_startsWithNick msg
    if @_fromUs
      msg = "(#{msg})"
    else if /[a-zA-Z0-9]$/.test msg
      msg = "#{msg}."
    return msg

  _youIsToYouAre: (you, msg) ->
    if msg.indexOf "#{you} is" isnt -1
      return msg.replace "#{you} is", "#{you} are"
    return msg

  ##
  # Returns true if the given message starts with the nick the message pertains
  # to or the nick the message is being sent from.
  ##
  _startsWithNick: (msg) ->
    startsWithToNick = msg.indexOf(@_to) is 0 and not @_toUs
    startsWithFromNick = msg.indexOf(@_from) is 0 and not @_fromUs
    startsWithToNick or startsWithFromNick

  ##
  # Clears the current style and adds the given style.
  # @param {string} style
  ##
  setStyle: (style) ->
    @_style = [style]

  ##
  # Adds the given style.
  # @param {Array.<string>} style
  ##
  addStyle: (style) ->
    style = [style] if not Array.isArray style
    @_style = @_style.concat style

  ##
  #
  ##
  hasStyle: (style) ->
    return style in @_customStyle or style in @_style

  ##
  # Returns the style of the message.
  # @param {string} style The combination of the added styles and custom styles.
  # @return {string} A space delimited string of styles to apply to the message.
  ##
  getStyle: ->
    style = @_customStyle.concat @_style
    style.push 'self' if @_fromUs or @_toUs
    return style.join ' '

  ##
  # Returns true if the user's nick equals the given nick.
  # @param nick The nick the check against
  # @return {boolean}
  ##
  _isOwnNick: (nick) ->
    irc.util.nicksEqual @_nick, nick

exports.MessageFormatter = MessageFormatter