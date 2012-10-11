describe 'An IRC client front end', ->
  client = undefined
  divs = ['chat', 'status', 'channels']

  prompt = $ '<div>'
  commandInput = new UserInputHandler(prompt, $ window)

  type = (text) ->
    prompt.val(text)
    commandInput._handleKeydown { which: 13, preventDefault: -> }

  addHTMLFixtures = ->
    for div in divs
      addMockDiv div

  addMockDiv = (id) ->
    div = $ "<div id='#{id}' style='display: hidden'>"
    $('body').append div

  removeHTMLFixtures = ->
    for div in divs
      $("##{div}").remove()

  init = ->
    scriptHandler = new window.script.ScriptHandler
    client = new window.chat.Chat

    commandInput.setContext client

    scriptHandler.addEventsFrom client
    scriptHandler.addEventsFrom commandInput
    scriptHandler.listenToScriptEvents client

    client.listenToCommands scriptHandler
    client.listenToScriptEvents scriptHandler
    client.listenToIRCEvents scriptHandler

  beforeEach ->
    addHTMLFixtures()
    mocks.ChromeSocket.use()
    mocks.NickMentionedNotification.use()
    chrome.storage.sync.set {nick: 'ournick'}
    init()

  afterEach ->
    removeHTMLFixtures()

  it "loads the previously used nick", ->
    expect($ '#status').toHaveText '[ournick]'

  it "sets the document title to the version", ->
    expect(document.title).toMatch /^CIRC [0-9].[0-9].[0-9]$/

  it "initially has one window", ->
    expect($('li', '#channels').length).toBe 1

  it "replaces the initial window with a server window on /connect", ->
    type '/connect freenode'
    expect($('li', '#channels').length).toBe 1
    expect(client.currentWindow.conn.name).toBe 'freenode'

  it "ignores commands that require a connection not connected", ->
    type '/names'
    type '/join #bash'
    type '/op bob'
    type '/msg someguy'
    type '/mode sally +o'

  describe "that connects", ->
    irc = undefined

    beforeEach ->
      type '/server freenode'
      irc = client.currentWindow.conn.irc
      irc.handle '1', {}, 'ournick' # rpl_welcome
      spyOn irc, 'doCommand'

    it "marks the server item in the window list as connected", ->
      expect($('li', '#channels').children()).toHaveText 'freenode'

    it "updates the status bar on /away", ->
      type '/away'
      irc.handle '306' # rpl_nowaway
      expect($ '#status').toHaveText '[ournick] (away)'

    it "creates a new window when a direct private message is received", ->
      irc.handle 'PRIVMSG', {nick: 'someguy'}, 'ournick', 'hi there'
      expect($('li', '#channels').length).toBe 2
      expect($('li', '#channels').last().children()).toHaveText 'someguy'
      expect($('li', '#channels').last()).toHaveClass 'mention'
      expect($('li', '#channels').last()).toHaveClass 'activity'
      expect($('li', '#channels').last()).not.toHaveClass 'selected'

    it "displays /msg text in the current window if there is no existing conversation window", ->
      spyOn(client.currentWindow, 'message').andCallThrough()
      type '/msg someguy hey dude'
      expect($('li', '#channels').length).toBe 1
      expect(client.currentWindow.message).toHaveBeenCalled()

    it "displays /msg text in the conversation window when it exists", ->
      irc.handle 'PRIVMSG', {nick: 'someguy'}, 'ournick', 'hi there'
      spyOn(client.currentWindow, 'message').andCallThrough()
      type '/msg someguy hey dude'
      expect(client.currentWindow.message).not.toHaveBeenCalled()

    it "/msg causes the conversation window to be marked with activity", ->
      irc.handle 'PRIVMSG', {nick: 'someguy'}, 'ournick', 'hi there'
      type '/win 2'
      type '/win 1'
      expect($('li', '#channels').last()).not.toHaveClass 'mention'
      expect($('li', '#channels').last()).not.toHaveClass 'activity'
      expect($('li', '#channels').last()).not.toHaveClass 'selected'
      type '/msg someguy hey dude'
      expect($('li', '#channels').last()).not.toHaveClass 'mention'
      expect($('li', '#channels').last()).toHaveClass 'activity'
      expect($('li', '#channels').last()).not.toHaveClass 'selected'

    it "creates a notification when a direct private message is received", ->
      chat.NickMentionedNotification.notificationCount = 0
      irc.handle 'PRIVMSG', {nick: 'someguy'}, 'ournick', 'hey!'
      expect(chat.NickMentionedNotification.notificationCount).toBe 1

    it "can join a channel with /join", ->
      type '/join #bash'
      expect(irc.doCommand).toHaveBeenCalledWith 'JOIN', '#bash'
      expect(client.currentWindow.target).toBe '#bash'

    describe "then joins a channel", ->

      beforeEach ->
        type '/join #bash'
        irc.handle 'JOIN', {nick: 'ournick'}, '#bash'

      it "adds another item to the window display", ->
        expect($('li', '#channels').length).toBe 2

      it "can switch windows with /win", ->
        type "/win 1"
        expect(client.currentWindow.target).toBe undefined

      it "creates a notification when the users nick is mentioned", ->
        type "/win 1"
        chat.NickMentionedNotification.notificationCount = 0
        irc.handle 'PRIVMSG', {nick: 'someguy'}, '#bash', 'hey ournick!'
        expect(chat.NickMentionedNotification.notificationCount).toBe 1
        expect($('li', '#channels').last()).toHaveClass 'mention'
        expect($('li', '#channels').last()).toHaveClass 'activity'
        expect($('li', '#channels').last()).not.toHaveClass 'selected'

      it "clears activity and mention style when switching to a window", ->
        type "/win 1"
        irc.handle 'PRIVMSG', {nick: 'someguy'}, '#bash', 'hey!'
        type "/win 2"
        expect($('li', '#channels').last()).not.toHaveClass 'mention'
        expect($('li', '#channels').last()).not.toHaveClass 'activity'
        expect($('li', '#channels').last()).toHaveClass 'selected'