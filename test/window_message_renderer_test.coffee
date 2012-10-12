describe "A window message renderer", ->
  surface = renderer = undefined

  message = (num) ->
    msg = $ $('.message', surface)[num]
    { source: $(msg.children()[0]), message: $(msg.children()[1]) }

  beforeEach ->
    surface = $ '<div>'
    renderer = new chat.window.MessageRenderer surface
    spyOn(renderer, '_addMessage').andCallThrough()

  afterEach ->
    surface.remove()

  it "displayes messages to the user", ->
    renderer.message 'bob', 'hi'
    expect(message(0).source).toHaveText 'bob'
    expect(message(0).message).toHaveText 'hi'

  it "escapes html-like text", ->
    renderer.message 'joe', '<a "evil.jpg"/>'
    expect(renderer._addMessage).toHaveBeenCalledWith 'joe',
        '&lt;a&emsp;<wbr>&quot;evil.jpg&quot;/&gt;', ''

  it "doesn't collapse multiple spaces", ->
    renderer.message 'bill', 'hi     there'
    expect(renderer._addMessage).toHaveBeenCalledWith 'bill',
        'hi&emsp;<wbr>&emsp;<wbr>&emsp;<wbr>&emsp;<wbr>&emsp;<wbr>there', ''

  it "auto-links urls", ->
    renderer.message '*', 'check www.youtube.com out'
    expect(renderer._addMessage).toHaveBeenCalledWith '*',
        'check&emsp;<wbr><a target="_blank" href="http://www.youtube.com">' +
        'www.youtube.com</a>&emsp;<wbr>out', ''

  it "allows long words to break", ->
    word = 'thisisareallyreallyreallyreallyreallyreallyreallylongword'
    renderer.message 'bill', word
    expect(renderer._addMessage).toHaveBeenCalledWith 'bill',
        '<span class="longword">' + word + '</span>', ''

  it "allows multiple long words to break", ->
    word1 = 'thisisareallyreallyreallyreallyreallyreallyreallylongword'
    word2 = 'andthisisalsoareallylongword!!!!!!!!!!!!!!!!!'
    renderer.message 'joe', word1 + ' ' + word2
    expect(renderer._addMessage).toHaveBeenCalledWith 'joe',
        '<span class="longword">' + word1 + '</span>&emsp;<wbr>' +
        '<span class="longword">' + word2 + '</span>', ''

  it "allows long words to break even when they contain HTML", ->
    word = 'thisisareallyreallyrea"<>&><"lyreallyreallyreallylongword'
    renderer.message 'bill', word
    escapedWord = word[..21] + '&quot;&lt;&gt;&amp;&gt;&lt;&quot;' + word[29..]
    expect(renderer._addMessage).toHaveBeenCalledWith 'bill',
        '<span class="longword">' + escapedWord + '</span>', ''

  it "doesn't allow short words that seem long due to HTML escaping to break", ->
    renderer.message 'joe', '<a href="evil.jpg"/>'
    expect(renderer._addMessage).toHaveBeenCalledWith 'joe',
        '&lt;a&emsp;<wbr>href=&quot;evil.jpg&quot;/&gt;', ''