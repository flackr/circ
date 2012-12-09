exports = (window.chat ?= {}).window ?= {}

##
# Displays help messages to the user, such as listing the available commands or
# keyboard shortcuts.
##
class HelpMessageRenderer

  # The total width of the help message, in number of characters (excluding
  # spaces)
  @TOTAL_WIDTH: 50

  # The order that command categories are displayed to the user.
  @CATEGORY_ORDER: ['common', 'uncommon', 'one_identity', 'scripts', 'misc']

  @COMMAND_STYLE: 'notice help monospace group'

  ##
  # @param {function(opt_message, opt_style)} postMessage
  ##
  constructor: (postMessage) ->
    @_postMessage = postMessage
    @_commands = {}
    @_maxCommandWidth = 0
    @_commandsPerLine = 0

  ##
  # Displays a help message for the given commands, grouped by category.
  # @param {Object.<string: {category: string}>} commands
  ##
  render: (commands) ->
    @_commands = commands
    @_addWhitespace()
    @_printCommands()
    @_postMessage "Type '/help <command>' to see details about a specific command.",
        'notice help'
    @_postMessage "Type '/hotkeys' to see the list of keyboard shortcuts.",
        'notice help'

  _printCommands: ->
    @_determineCommandDimentions()
    for group in @_groupCommandsByCategory()
      @_postMessage "#{@_getCommandGroupName group.category} Commands:",
          HelpMessageRenderer.COMMAND_STYLE
      @_addWhitespace()
      @_printCommandGroup group.commands.sort()
      @_addWhitespace()

  _determineCommandDimentions: ->
    totalWidth = HelpMessageRenderer.TOTAL_WIDTH
    @_maxCommandWidth = @_getMaxCommandLength()
    @_commandsPerLine =  Math.floor totalWidth / @_maxCommandWidth

  ##
  # @return {number} Returns the number of characters in the longest command.
  ##
  _getMaxCommandLength: ->
    maxLength = 0
    for command of @_commands
      if command.length > maxLength
        maxLength = command.length
    maxLength

  ##
  # Returns a map of categories mapped to command names.
  # @return {Array.<{string: Array.<string>}>}
  ##
  _groupCommandsByCategory: ->
    categoryToCommands = {}
    for name, command of @_commands
      continue if command.category is 'hidden'
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
    for category in HelpMessageRenderer.CATEGORY_ORDER
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
      when 'scripts' then 'Script'
      else 'Misc'

  ##
  # Print an array of commands.
  # @param {Array.<string>} commands
  ##
  _printCommandGroup: (commands) ->
    line = []
    for command, i in commands
      isLastMessageInRow = line.length >= @_commandsPerLine - 1 or
          i >= commands.length - 1
      if isLastMessageInRow
        line.push command
        @_postMessage '  ' + line.join(' '), HelpMessageRenderer.COMMAND_STYLE
        line = []
      else
        line.push @_fillWithWhiteSpace command

  _fillWithWhiteSpace: (command) ->
    space = (' ' for i in [0..@_maxCommandWidth-command.length]).join ''
    return command + space

  ##
  # Display a help message detailing the available hotkeys.
  # @param {Object.<string: {description: string, group: string,
  #     readableName: string}>} hotkeys
  ##
  renderHotkeys: (hotkeys) ->
    @_addWhitespace()
    @_postMessage "Keyboard Shortcuts:", 'notice help'
    @_addWhitespace()
    @_printHotkeys hotkeys

  ##
  # Displays a list of hotkeys and their descriptions.
  # @param {Object.<string: {description: string, group: string,
  #     readableName: string}>} hotkeys
  ##
  _printHotkeys: (hotkeys) ->
    groupsVisited = {}
    for id, hotkeyInfo of hotkeys
      if hotkeyInfo.group
        continue if hotkeyInfo.group of groupsVisited
        groupsVisited[hotkeyInfo.group] = true
        name = hotkeyInfo.group
      else
        name = hotkeyInfo.readableName
      @_postMessage "  #{name}: #{hotkeyInfo.description}", 'notice help'

  _addWhitespace: ->
    @_postMessage()

exports.HelpMessageRenderer = HelpMessageRenderer