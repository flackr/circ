exports = window.chat ?= {}

##
# A UI element to inform and/or prompt the user.
##
class Notice

  constructor: ->
    @$notice = $ '#notice'
    @$content = $ '#notice .content'
    @$close = $ '#notice button.close'
    @$option1 = $ '#notice button.option1'
    @$option2 = $ '#notice button.option2'

    @$close.click => @_hide()

  ##
  # Display a message to the user.
  # The prompt representation has the following format:
  #   "message_text [button_1_text] [button_2_text]"
  #
  # @param {string} representation A string representation of the message.
  # @param {...function} callbacks Specifies what function should be called when
  #     an option is clicked.
  ##
  prompt: (representation, callbacks...) ->
    @_hide()
    @_callbacks = callbacks
    @_parseRepresentation representation
    @$option1.click => @_hide(); @_callbacks[0]?()
    @$option2.click => @_hide(); @_callbacks[1]?()
    @_show()

  close: ->
    @_hide()

  _hide: ->
    @$notice[0].style.top = "-35px"
    @$option1.off 'click'
    @$option2.off 'click'

  _show: ->
    @$notice[0].style.top = "0px"

  _parseRepresentation: (representation) ->
    @_setMessageText representation
    options = representation.match /\[.+?\]/g
    @_setOptionText @$option1, options?[0]
    @_setOptionText @$option2, options?[1]

  _setMessageText: (representation) ->
    representation = representation.split('[')[0]
    @$content.text $.trim representation

  _setOptionText: (button, textWithBrackets) ->
    if textWithBrackets
      text = textWithBrackets[1..textWithBrackets.length - 2]
      button.removeClass 'hidden'
      button.text text
    else if not button.hasClass 'hidden'
      button.addClass 'hidden'

exports.Notice = Notice