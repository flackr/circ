exports = (window.chat ?= {}).window ?= {}

##
# Handles outputing text to the window and provides functions to display
# some specific messages like help and about.
##
class MessageRenderer

  @PROJECT_URL: "http://noahsug.github.com/circ"

  constructor: (@win) ->
    @_userSawMostRecentMessage = false
    @_activityMarkerLocation = undefined
    @_helpMessageRenderer = new exports.HelpMessageRenderer @systemMessage

  onFocus: ->
    @_userSawMostRecentMessage = @win.$messages.children().length > 0

  displayWelcome: ->
    @_addWhitespace()
    @systemMessage "Welcome to CIRC!"
    @systemMessage @_getWebsiteBlurb()

  ##
  # Display available commands, grouped by category.
  # @param {Object.<string: {category: string}>} commands
  ##
  displayHelp: (commands) ->
    @_helpMessageRenderer.render commands

  displayAbout: ->
    @_addWhitespace()
    @systemMessage "CIRC is a packaged Chrome app developed by Google Inc. " +
        @_getWebsiteBlurb(), 'notice about'
    @systemMessage "Version: #{irc.VERSION}", 'notice about'
    @systemMessage "Contributors:", 'notice about group'
    @systemMessage "    * UI mocks by Fravic Fernando (fravicf@gmail.com)",
        'notice about group'

  _getWebsiteBlurb: ->
    "Documentation, issues and source code live at " +
        "#{MessageRenderer.PROJECT_URL}."

  message: (from='', msg='', style...) ->
    wasScrolledDown = @win.isScrolledDown()
    from = html.escape from
    msg = html.display msg
    style = style.join ' '
    @_addMessage from, msg, style
    if wasScrolledDown
      @win.scrollToBottom()
    @_updateActivityMarker() if @_shouldUpdateActivityMarker()

  ##
  # Display a system message to the user. A system message has no from field.
  ##
  systemMessage: (msg='', style='system') =>
    @message '', msg, style

  _addMessage: (from, msg, style) ->
    message = $('#templates .message').clone()
    message.addClass style
    $('.source', message).html from
    $('.content', message).html msg
    $('.source', message).addClass('empty') unless from
    @win.emit 'message', @win.getContext(), style, message[0].outerHTML
    @win.$messages.append message

  _addWhitespace: ->
    @message()

  ##
  # Update the activity marker when the user has seen the most recent messages
  # and then received a message while the window wasn't focused.
  ##
  _shouldUpdateActivityMarker: ->
    return not @win.isFocused() and @_userSawMostRecentMessage

  _updateActivityMarker: ->
    @_userSawMostRecentMessage = false
    if @_activityMarkerLocation
      @_activityMarkerLocation.removeClass 'activity-marker'
    @_activityMarkerLocation = @win.$messages.children().last()
    @_activityMarkerLocation.addClass 'activity-marker'

exports.MessageRenderer = MessageRenderer