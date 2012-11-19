exports = (window.chat ?= {}).window ?= {}

##
# Handles outputing text to the window and provides functions to display
# some specific messages like help and about.
##
class MessageRenderer

  @PROJECT_URL = "noahsug.github.com/circ"

  constructor: (@win) ->
    @_resetActivityMarker = false
    @_activityMarkerLocation = undefined

  onFocus: ->
    @_resetActivityMarker = @win.$messages.children().length > 0

  displayWelcome: ->
    @message()
    @message '', "Welcome to CIRC!", 'system'
    @message '', @_getWebsiteBlurb(), 'system'

  displayHelp: (commands) ->
    @message()
    @message '', "Commands Available:", 'notice help'
    @_printCommands commands
    @message '', "Type /help <command> to see details about a specific command.",
        'notice help'
    @message '', @_getWebsiteBlurb(), 'notice help'

  displayAbout: ->
    @message()
    @message '', "CIRC is a packaged Chrome app developed by Google Inc. " +
        @_getWebsiteBlurb(), 'notice about'
    @message '', "Version: #{irc.VERSION}", 'notice about'
    @message '', "Contributors:", 'notice about group'
    @message '', "    * UI mocks by Fravic Fernando (fravicf@gmail.com)", 'notice about group'

  _getWebsiteBlurb: ->
    "Documentation, issues and source code live at " +
        "#{MessageRenderer.PROJECT_URL}."

  _printCommands: (commands) ->
    maxWidth = 40
    style = 'notice help monospace group'
    widthPerCommand = @_getMaxCommandWidth commands
    commandsPerLine = maxWidth / Math.floor widthPerCommand
    line = []
    for command, i in commands
      line.push @_fillWithWhiteSpace command, widthPerCommand
      if line.length >= commandsPerLine or i >= commands.length - 1
        @message '', line.join('  '), style
        line = []

  _getMaxCommandWidth: (commands) ->
    maxWidth = 0
    for command in commands
      if command.length > maxWidth
        maxWidth = command.length
    maxWidth

  _fillWithWhiteSpace: (command, maxCommandWidth) ->
    space = (' ' for i in [0..maxCommandWidth-1]).join ''
    return command + space.slice 0, maxCommandWidth - command.length

  message: (from='', msg='', style...) ->
    wasScrolledDown = @win.isScrolledDown()
    from = html.escape from
    msg = html.display msg
    style = style.join ' '
    @_addMessage from, msg, style
    if wasScrolledDown
      @win.scrollToBottom()
    @_displayActivityMarker() if @_shouldDisplayActivityMarker()

  _addMessage: (from, msg, style) ->
    message = $('#templates .message').clone()
    message.addClass style
    $('.source', message).html from
    $('.content', message).html msg
    $('.source', message).addClass('empty') unless from
    @win.emit 'message', @win.getContext(), style, message[0].outerHTML
    @win.$messages.append message

  _shouldDisplayActivityMarker: ->
    return not @win.isFocused() and @_resetActivityMarker

  _displayActivityMarker: ->
    @_resetActivityMarker = false
    if @_activityMarkerLocation
      @_activityMarkerLocation.removeClass 'activity-marker'
    @_activityMarkerLocation = @win.$messages.children().last()
    @_activityMarkerLocation.addClass 'activity-marker'

exports.MessageRenderer = MessageRenderer