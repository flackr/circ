describe "A window message renderer", ->
  surface = renderer = undefined

  message = (num) ->
    msg = $ $('.message', surface)[num]
    { source: $(msg.children()[0]), content: $(msg.children()[1]) }

  beforeEach ->
    mocks.dom.setUp()
    surface = $ '<div>'
    win =
      $messages: surface
      $messagesContainer: $ '<#messages-container>'
      isScrolledDown: ->
      scrollToBottom: ->
      getContext: -> {}
      emit: ->
      isFocused: -> true
    win.$messagesContainer.restoreScrollPosition = ->
    renderer = new chat.window.MessageRenderer win
    spyOn(renderer, '_createContentFromText').andCallThrough()

  content = ->
    args = renderer._createContentFromText.mostRecentCall.args
    html.display args[0]

  afterEach ->
    mocks.dom.tearDown()
    surface.remove()

  it "displays messages to the user", ->
    renderer.message 'bob', 'hi'
    expect(message(0).source).toHaveText 'bob'
    expect(message(0).content).toHaveText 'hi'

  it "escapes html-like text", ->
    renderer.message 'joe', '<a "evil.jpg"/>'
    expect(content()).toBe '&lt;a &quot;evil.jpg&quot;/&gt;'

  it "doesn't collapse multiple spaces", ->
    renderer.message 'bill', 'hi     there'
    expect(content()).toBe 'hi     there', ''

  it "auto-links urls", ->
    renderer.message '*', 'check www.youtube.com out'
    expect(content()).toBe 'check <a target="_blank" ' +
        'href="http://www.youtube.com">www.youtube.com</a> out'

  it "allows long words to break", ->
    word = 'thisisareallyreallyreallyreallyreallyreallyreallylongword'
    renderer.message 'bill', word
    expect(content()).toBe '<span class="longword">' + word + '</span>'

  it "allows multiple long words to break", ->
    word1 = 'thisisareallyreallyreallyreallyreallyreallyreallylongword'
    word2 = 'andthisisalsoareallylongword!!!!!!!!!!!!!!!!!'
    renderer.message 'joe', word1 + ' ' + word2
    expect(content()).toBe '<span class="longword">' + word1 + '</span> ' +
        '<span class="longword">' + word2 + '</span>'

  it "allows the same long word to be used twice", ->
    word = 'andthisisalsoareallylongwordddddddddddddd'
    renderer.message 'joe', word + ' ' + word
    expect(content()).toBe '<span class="longword">' + word + '</span> ' +
        '<span class="longword">' + word + '</span>'

  it "allows long words to break even when they contain HTML", ->
    word = 'thisisareallyreallyrea"<>&><"lyreallyreallyreallylongword'
    renderer.message 'bill', word
    escapedWord = word[..21] + '&quot;&lt;&gt;&amp;&gt;&lt;&quot;' + word[29..]
    expect(content()).toBe '<span class="longword">' + escapedWord + '</span>'

  it "doesn't allow short words that seem long due to HTML escaping to break", ->
    renderer.message 'joe', '<a href="evil.jpg"/>'
    expect(content()).toBe '&lt;a href=&quot;evil.jpg&quot;/&gt;'