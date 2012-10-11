exports = window.chat ?= {}

class Window
  ##
  # The screen will auto scroll as long as the user didn't scroll up more then
  # this many pixels.
  ##
  @SCROLLED_DOWN_BUFFER = 8

  constructor: (server, opt_channel) ->
    @name = server + if opt_channel then " #{opt_channel}" else ''
    @wasScrolledDown = true
    @$container = $ "<div id='window-container'>"
    @$messages = $ "<div id='chat-messages'>"
    @$chatDisplay = $ "<div id='chat-display'>"
    chatDisplayContainer = $ "<div id='chat-display-container'>"
    chatDisplayContainer.append @$chatDisplay
    @$chatDisplay.append @$messages
    @$container.append chatDisplayContainer

  setTarget: (@target) ->
    @_addNickList() unless @isPrivate()

  isServerWindow: ->
    return not @target?

  equals: (win) ->
    return @name is win.name

  ##
  # Marks the window as private.
  # Private windows are used for direct messages from /msg.
  ##
  makePrivate: ->
    @$nickWrapper?.remove()
    @_private = true

  isPrivate: ->
    return @_private?

  _addNickList: ->
    nicks = $ "<ol id='nicks'>"
    nickDisplay = $ "<div id='nick-display'>"
    @$nickWrapper = $ "<div id='nick-display-container'>"
    nickDisplay.append nicks
    @$nickWrapper.append nickDisplay
    @$container.append @$nickWrapper
    @nicks = new chat.NickList(nicks)

  detach: ->
    @scroll = @$chatDisplay.scrollTop()
    @wasScrolledDown = @isScrolledDown()
    @$container.detach()

  remove: ->
    @$container.remove()

  attachTo: (container) ->
    container.prepend @$container
    if @wasScrolledDown
      @scroll = @$chatDisplay[0].scrollHeight
    @$chatDisplay.scrollTop(@scroll)

  isScrolledDown: ->
    scrollPosition = @$chatDisplay.scrollTop() + @$chatDisplay.height()
    scrollPosition >= @$chatDisplay[0].scrollHeight - Window.SCROLLED_DOWN_BUFFER

  emptyLine: () ->
    @_addMessage '&nbsp;', '&nbsp;'

  message: (from, msg, style...) ->
    @_addMessage escapeHTML(from), display(msg), style...

  _addMessage: (from, msg, classes...) ->
    wasScrolledDown = @isScrolledDown()
    @$messages.append $("""
    <div class='message #{classes.join(' ')}'>
      <div class='source'>#{from}</div>
      <div class='text'>#{msg}</div>
    </div>
    """)
    if wasScrolledDown
      @scrollToBottom()

  scrollToBottom: ->
    @$chatDisplay.scrollTop(@$chatDisplay[0].scrollHeight)

  displayHelp: (commands) ->
    # TODO format nicely
    commandList = ('/'+c for c in commands).join(' ')
    @message '*', "Commands Available: #{commandList}", 'notice help'

escapeHTML = (html) ->
  escaped = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
  }
  String(html).replace(/[&<>"]/g, (chr) -> escaped[chr])

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
    escapeHTML(str).replace(/\S{40,}/,'<span class="longword">$&</span>')
  res = ''
  textIndex = 0
  while m = rurl.exec text
    res += escape(text.substr(textIndex, m.index - textIndex))
    res += '<a target="_blank" href="'+canonicalise(m[0])+'">'+escape(m[0])+'</a>'
    textIndex = m.index + m[0].length
  res += escape(text.substr(textIndex))
  return res

exports.Window = Window