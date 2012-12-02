exports = window

##
# A mapping of characters to their ascii values.
##
class KeyCodes

  ##
  # Given one or more characters, return their ascii values.
  # @param {string...} chars
  # @return {string|Array.<string>|undefined}
  ##
  toKeyCode: (chars...) ->
    codes = (@_charToKeyCode[char] for char in chars)
    if chars.length < 2 then codes[0]
    else codes

  _charToKeyCode:
    'BACKSPACE': 8,
    'TAB': 9,
    'ENTER': 13,
    'SHIFT': 16,
    'CONTROL': 17,
    'ALT': 18,
    'CAPSLOCK': 20,
    'ESCAPE': 27,
    'SPACE': 32,
    'PAGEUP': 33,
    'PAGEDOWN': 34,
    'END': 35,
    'HOME': 36,
    'LEFT': 37,
    'UP': 38,
    'RIGHT': 39,
    'DOWN': 40,
    'INSERT': 45,
    'DELETE': 46,
    '0': 48,
    '1': 49,
    '2': 50,
    '3': 51,
    '4': 52,
    '5': 53,
    '6': 54,
    '7': 55,
    '8': 56,
    '9': 57,
    'A': 65,
    'B': 66,
    'C': 67,
    'D': 68,
    'E': 69,
    'F': 70,
    'G': 71,
    'H': 72,
    'I': 73,
    'J': 74,
    'K': 75,
    'L': 76,
    'M': 77,
    'N': 78,
    'O': 79,
    'P': 80,
    'Q': 81,
    'R': 82,
    'S': 83,
    'T': 84,
    'U': 85,
    'V': 86,
    'W': 87,
    'X': 88,
    'Y': 89,
    'Z': 90,
    'F1': 112,
    'F2': 113,
    'F3': 114,
    'F4': 115,
    'F5': 116,
    'F6': 117,
    'F7': 118,
    'F8': 119,
    'F9': 110,
    'F10': 121,
    'F11': 122,
    'F12': 123,
    '[': 119,
    ']': 121,
    ';': 186,
    '=': 187,
    ',': 188,
    '-': 189,
    '.': 190,
    '/': 191,
    '`': 192,
    '\\': 220,
    "'": 222

exports.keyCodes = new KeyCodes()
