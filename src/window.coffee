exports = window.chat ?= {}

class Window
  constructor: (@name) ->
    @$container = $ "<div id='chat-container'>"
    @$messages = $ "<div id='chat'>"
    @$container.append @$messages

  isScrolledDown: ->
    scrollBottom = @$container.scrollTop() + @$container.height()
    scrollBottom == @$container[0].scrollHeight

  message: (from, msg, opts={}) ->
    scroll = @isScrolledDown
    e = escapeHTML
    extra_classes = [opts.type]
    msg = display msg
    @$messages.append $("""
    <div class='message #{extra_classes.join(' ')}'>
      <div class='source'>#{e from}</div>
      <div class='text'>#{msg}</div>
    </div>
    """)
    if scroll
      @$container.scrollTop(@$container[0].scrollHeight)

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