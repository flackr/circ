exports = window

##
# Maps keyboard shortcuts to commands and their arguments.
##
class KeyboardShortcutMap

  ##
  # Returns the stringified name for the given keyboard shortcut.
  # @param {KeyboardEvent} e
  ##
  @getShortcutName: (e) ->
    name = []
    name.push 'Ctrl' if e.ctrlKey
    name.push 'Meta' if e.metaKey
    name.push 'Alt' if e.altKey
    name.push 'Shift' if e.shiftKey
    name.push e.which
    return name.join '-'

  ##
  # These keys can be mapped to shortcuts without needing a modifier key to be
  # down.
  ##
  @SHORTCUT_KEYS = keyCodes.toKeyCode 'PAGEUP', 'PAGEDOWN', 'CAPSLOCK', 'INSERT',
      'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'

  ##
  # These keys can be mapped to shortcuts without needing a modifier key to be
  # down, but only if there is no input entered.
  ##
  @SHORTCUT_KEYS_WHEN_NO_INPUT = [keyCodes.toKeyCode 'TAB']

  constructor: ->
    @_shortcutMap = {}
    @_mapShortcuts()

  ##
  # Get the command for the given shortcut if it is valid.
  # @param {KeyboardEvent} shortcut
  # @param {boolean} hasInput True if the input DOM element has text.
  # @return {[string, Array.<Object>]} Returns the name of the command with its
  #     arguments
  ##
  getMappedCommand: (shortcut, hasInput) ->
    return [] unless @_isValidShortcut shortcut, hasInput
    shortcutName = KeyboardShortcutMap.getShortcutName shortcut
    return [] unless @_isMapped shortcutName
    command = @_shortcutMap[shortcutName].command
    args = @_shortcutMap[shortcutName].args
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
    else if keyEvent.which in KeyboardShortcutMap.SHORTCUT_KEYS
      true
    else
      not hasInput and keyEvent.which in
          KeyboardShortcutMap.SHORTCUT_KEYS_WHEN_NO_INPUT

  ##
  # Returns true if the given shortcut has a command mapped to it.
  # @param {string} shortcutName
  # @return {boolean}
  ##
  _isMapped: (shortcutName) ->
    shortcutName of @_shortcutMap

  ##
  # Maps shortcuts to commands and their arguments.
  # Note: The modifier key order is important and must be consistant with
  # getShortcutName().
  ##
  _mapShortcuts: ->
    for windowNumber in [1..9]
      @_addShortcut "Alt-#{windowNumber}",
        command: 'win'
        args: [windowNumber]

    @_addShortcut 'Alt-S',
      command: 'next-server'

    @_addShortcut 'Alt-DOWN',
      command: 'next-room'

    @_addShortcut 'Alt-UP',
      command: 'previous-room'

    @_addShortcut 'TAB',
      command: 'reply'

    @_addShortcut 'PAGEUP',
      command: 'pageup'

    @_addShortcut 'PAGEDOWN',
      command: 'pageup'

    @_addShortcut 'Ctrl-F',
      command: 'search'

    @_addShortcut 'Ctrl-HOME',
      command: 'scroll-to-top'

    @_addShortcut 'Ctrl-END',
      command: 'scroll-to-bottom'

  _addShortcut: (name, description) ->
    name = @_charToKeyCode name
    description.args ?= []
    @_shortcutMap[name] = description

  ##
  # Convert a readable command name to a key code command name.
  # (e.g. 'Alt-S' becomes 'Alt-115').
  ##
  _charToKeyCode: (name) ->
    parts = name.split '-'
    char = parts[parts.length - 1]
    parts[parts.length - 1] = keyCodes.toKeyCode char
    parts.join '-'

exports.KeyboardShortcutMap = KeyboardShortcutMap