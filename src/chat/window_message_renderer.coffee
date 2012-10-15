exports = (window.chat ?= {}).window ?= {}

class MessageRenderer

  @WIKI_URL = "https://github.com/noahsug/circ/wiki"

  constructor: (@win) ->

  displayEmptyLine: ->
    @message()

  displayWelcome: ->
    @message '', "Welcome to CIRC, a packaged Chrome app.", "system"
    @displayEmptyLine()
    @_displayWikiUrl('system')
    @displayEmptyLine()
    @message '', "Type /server <server> [port] to connect, then /nick <my_nick> and /join <#channel>.", "system"
    @displayEmptyLine()
    @message '', "Type /help to see a full list of commands.", "system"
    @displayEmptyLine()
    @message '', "Switch windows with alt+[0-9] or click in the channel list on the left.", "system"

  displayHelp: (commands) ->
    @displayEmptyLine()
    @message '*', "Commands Available:", 'notice help'
    @displayEmptyLine()
    @_printCommands commands
    @displayEmptyLine()
    @message '', "Type /help <command> to see details about a specific command.",
        'notice help'
    @displayEmptyLine()
    @_displayWikiUrl('notice help')

  displayAbout: ->
    @displayEmptyLine()
    @message '*', "CIRC is a packaged Chrome app developed by Google Inc. " +
    "The source code and documentation is available on GitHub at www.github.com/noahsug/circ.", 'notice about'
    @displayEmptyLine()
    @message '', "Contributors:", 'notice about'
    @message '', " * UI mocks by Fravic Fernando (fravicf@gmail.com)", 'notice about'

  _displayWikiUrl: (style) ->
    @message '', "Visit #{MessageRenderer.WIKI_URL} to read " +
        "documentation and give feedback.", style

  _printCommands: (commands) ->
    maxWidth = 40
    widthPerCommand = @_getMaxCommandWidth commands
    commandsPerLine = maxWidth / Math.floor widthPerCommand
    line = []
    for command, i in commands
      line.push @_fillWithWhiteSpace command, widthPerCommand
      if line.length >= commandsPerLine or i >= commands.length - 1
        @message '', line.join('  '), 'notice help'
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

  message: (from='', msg=' ', style...) ->
    wasScrolledDown = @win.isScrolledDown()
    from = escapeHTML from
    msg = display msg
    style = style.join ' '
    @_addMessage from, msg, style
    if wasScrolledDown
      @win.scrollToBottom()

  _addMessage: (from, msg, style) ->
    html = $('#templates .message').clone()
    html.addClass style
    $('.source', html).html from
    $('.content', html).html msg
    @win.$messages.append html

escapeHTML = (html) ->
  escaped = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    ' ': '&nbsp;<wbr>',
  }
  String(html).replace(/[\s&<>"]/g, (chr) -> escaped[chr])

display = (text) ->
  # Gruber's url-finding regex
  rurl = /\b((?:[a-z][\w-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))/gi
  canonicalise = (url) ->
    url = escapeHTML url
    if url.match(/^[a-z][\w-]+:/i)
      url
    else
      'http://' + url

  escape = (str) ->
    # long words need to be extracted before escaping so escape HTML characters
    # don't scew the word length
    longWords = str.match(/\S{40,}/g) ? []
    longWords = (escapeHTML(word) for word in longWords)
    str = escapeHTML(str)
    for word in longWords
      str = str.replace word, "<span class=\"longword\">#{word}</span>"
    str

  res = ''
  textIndex = 0
  while m = rurl.exec text
    res += escape(text.substr(textIndex, m.index - textIndex))
    res += '<a target="_blank" href="'+canonicalise(m[0])+'">'+escape(m[0])+'</a>'
    textIndex = m.index + m[0].length
  res += escape(text.substr(textIndex))
  return res

exports.MessageRenderer = MessageRenderer