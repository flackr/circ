exports = window

##
# Maps keyboard shortcuts to commands and their arguments.
##
class KeyboardShortcutMap

  ##
  # Returns the stringified name for the given keyboard shortcut.
  # @param {KeyboardEvent} e
  ##
  @getKeyCombination: (e) ->
    name = []
    name.push 'Ctrl' if e.ctrlKey
    name.push 'Meta' if e.metaKey
    name.push 'Alt' if e.altKey
    name.push 'Shift' if e.shiftKey
    name.push e.which
    return name.join '-'

  ##
  # These keys can be mapped to hotkeys without needing a modifier key to be
  # down.
  ##
  @NO_MODIFIER_HOTKEYS = keyCodes.toKeyCode 'PAGEUP', 'PAGEDOWN', 'CAPSLOCK', 'INSERT',
      'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'

  ##
  # These keys can be mapped to hotkeys without needing a modifier key to be
  # down, but only if there is no input entered.
  ##
  @NO_INPUT_HOTKEYS = [keyCodes.toKeyCode 'TAB']

  constructor: ->
    @_hotkeyMap = {}
    @_mapHotkeys()

  ##
  # Returns the mapping of hotkeys to commands.
  # @param {Object.<string: {description: string, group: string,
  #     readableName: string, command: string, args: Array<Object>}>} hotkeys
  ##
  getMap: ->
    @_hotkeyMap

  ##
  # Get the command for the given shortcut if it is valid.
  # @param {KeyboardEvent} shortcut
  # @param {boolean} hasInput True if the input DOM element has text.
  # @return {[string, Array.<Object>]} Returns the name of the command with its
  #     arguments
  ##
  getMappedCommand: (shortcut, hasInput) ->
    return [] unless @_isValidShortcut shortcut, hasInput
    keyCombination = KeyboardShortcutMap.getKeyCombination shortcut
    return [] unless @_isMapped keyCombination
    command = @_hotkeyMap[keyCombination].command
    args = @_hotkeyMap[keyCombination].args
    [command, args]

  ##
  # Returns true if the given keyboard input event is a valid keyboard shortcut.
  # @param {KeyboardEvent} shortcut
  # @param {boolean} hasInput True if the input DOM element has text.
  # @return {boolean}
  ##
  _isValidShortcut: (keyEvent, hasInput) ->
    if keyEvent.metaKey or keyEvent.ctrlKey or keyEvent.altKey
      true
    else if keyEvent.which in KeyboardShortcutMap.NO_MODIFIER_HOTKEYS
      true
    else
      not hasInput and keyEvent.which in
          KeyboardShortcutMap.NO_INPUT_HOTKEYS

  ##
  # Returns true if the given shortcut has a command mapped to it.
  # @param {string} shortcutName
  # @return {boolean}
  ##
  _isMapped: (keyCombination) ->
    keyCombination of @_hotkeyMap

  ##
  # Maps hotkeys to commands and their arguments.
  # Note: The modifier key order is important and must be consistant with
  # getKeyCombination().
  # * command: What command the hotkey maps to.
  # * group: What group of hotkeys the hotkey belongs to.
  # * description: A quick description of the command. The command name is used by default.
  # * args: What args should be passed in to the command.
  ##
  _mapHotkeys: ->
    for windowNumber in [1..9]
      @_addHotkey "Alt-#{windowNumber}",
        command: 'win'
        group: 'Alt-#'
        description: 'switch channels'
        args: [windowNumber]

    @_addHotkey 'Alt-S',
      command: 'next-server'

    @_addHotkey 'Alt-DOWN',
      command: 'next-room'

    @_addHotkey 'Alt-UP',
      command: 'previous-room'

    @_addHotkey 'TAB',
      command: 'reply'
      description: 'autocomplete or reply to last mention'

# TODO: Implement the following commands:
#
#    @_addHotkey 'PAGEUP',
#      command: 'pageup'
#
#    @_addHotkey 'PAGEDOWN',
#      command: 'pageup'
#
#    @_addHotkey 'Ctrl-F',
#      command: 'search'
#
#    @_addHotkey 'Ctrl-HOME',
#      command: 'scroll-to-top'
#
#    @_addHotkey 'Ctrl-END',
#      command: 'scroll-to-bottom'

  _addHotkey: (keyCombination, description) ->
    hotkeyCode = @_getHotkeyCode keyCombination
    description.args ?= []
    @_hotkeyMap[hotkeyCode] = description
    @_hotkeyMap[hotkeyCode].readableName = keyCombination
    if description.description
      @_hotkeyMap[hotkeyCode].description = description.description
    else
      @_hotkeyMap[hotkeyCode].description = description.command.replace /-/g, ' '
  ##
  # Convert a readable key combination into its key code value.
  # (e.g. 'Alt-S' becomes 'Alt-115').
  ##
  _getHotkeyCode: (keyCombination) ->
    parts = keyCombination.split '-'
    char = parts[parts.length - 1]
    parts[parts.length - 1] = keyCodes.toKeyCode char
    parts.join '-'

exports.KeyboardShortcutMap = KeyboardShortcutMap