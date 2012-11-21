exports = (window.chat ?= {}).window ?= {}

##
# Handles outputing text to the window and provides functions to display
# some specific messages like help and about.
##
class MessageRenderer

  @PROJECT_URL: "http://noahsug.github.com/circ"

  # The max width of the help message, in number of characters.
  @HELP_COMMAND_WIDTH: 50

  # The order in command groups are displayed to the user.
  @HELP_CATEGORY_ORDER: ['common', 'uncommon', 'one_identity', 'misc']

  constructor: (@win) ->
    @_userSawMostRecentMessage = false
    @_activityMarkerLocation = undefined

  onFocus: ->
    @_userSawMostRecentMessage = @win.$messages.children().length > 0

  displayWelcome: ->
    @message()
    @message '', "Welcome to CIRC!", 'system'
    @message '', @_getWebsiteBlurb(), 'system'

  ##
  # Display available commands, grouped by category.
  # @param {Object.<string: {category: string}>} commands
  ##
  displayHelp: (commands) ->
    @message()
    @_printCommands commands
    @message '', "Type /help <command> to see details about a specific command.",
        'notice help'
    @message '', @_getWebsiteBlurb(), 'notice help'

  _printCommands: (commands) ->
    totalWidth = MessageRenderer.HELP_COMMAND_WIDTH
    commandWidth = @_getMaxCommandLength commands
    commandsPerLine =  Math.floor totalWidth / commandWidth
    style = 'notice help monospace group'

    commandGroups = @_groupCommandsByCategory commands
    for group in commandGroups
      @message '', "#{@_getCommandGroupName group.category} Commands:", style
      @message()
      @_printCommandGroup group.commands, commandWidth, commandsPerLine, style
      @message()

  ##
  # Returns a map of categories mapped to command names.
  # @param {Object.<string: {category: string}>} commands
  # @return {Array.<{string: Array.<string>}>}
  ##
  _groupCommandsByCategory: (commands) ->
    categoryToCommands = {}
    for name, command of commands
      category = command.category ? 'misc'
      categoryToCommands[category] ?= []
      categoryToCommands[category].push name
    @_orderGroups categoryToCommands

  ##
  # Given a map of categories to commands, order the categories in the order
  # we'd like to display to the user.
  # @param {Object.<string: Array.<string>>} categoryToCommands
  # @return {Array.<{category: string, commands: Array.<string>}>}
  ##
  _orderGroups: (categoryToCommands) ->
    groups = []
    for category in MessageRenderer.HELP_CATEGORY_ORDER
      groups.push { category, commands: categoryToCommands[category] }
    groups

  ##
  # Given a category, return the name to display to the user.
  # @param {string} category
  # @return {string}
  ##
  _getCommandGroupName: (category) ->
    switch category
      when 'common' then 'Basic IRC'
      when 'uncommon' then 'Other IRC'
      when 'one_identity' then 'One Identity'
      else 'Misc'

  ##
  # Print an array of commands.
  # @param {Array.<string>} commands
  # @param {number} widthPerCommand
  # @param {number} commandsPerLine
  ##
  _printCommandGroup: (commands, commandWidth, commandsPerLine, style) ->
    line = []
    for command, i in commands
      line.push @_fillWithWhiteSpace command, commandWidth
      if line.length >= commandsPerLine or i >= commands.length - 1
        @message '', '  ' + line.join('  '), style
        line = []

  ##
  # @return {number} Returns the number of characters in the longest command.
  ##
  _getMaxCommandLength: (commands) ->
    maxLength = 0
    for command of commands
      if command.length > maxLength
        maxLength = command.length
    maxLength

  _fillWithWhiteSpace: (command, maxCommandLength) ->
    space = (' ' for i in [1..maxCommandLength-command.length]).join ''
    return command + space

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

  message: (from='', msg='', style...) ->
    wasScrolledDown = @win.isScrolledDown()
    from = html.escape from
    msg = html.display msg
    style = style.join ' '
    @_addMessage from, msg, style
    if wasScrolledDown
      @win.scrollToBottom()
    @_updateActivityMarker() if @_shouldUpdateActivityMarker()

  _addMessage: (from, msg, style) ->
    message = $('#templates .message').clone()
    message.addClass style
    $('.source', message).html from
    $('.content', message).html msg
    $('.source', message).addClass('empty') unless from
    @win.emit 'message', @win.getContext(), style, message[0].outerHTML
    @win.$messages.append message

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