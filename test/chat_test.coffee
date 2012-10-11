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

  restart = ->
    removeHTMLFixtures()
    addHTMLFixtures()
    init()

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
    mocks.ChromeSocket.useMock()
    mocks.NickMentionedNotification.useMock()
    chrome.storage.sync.set {nick: 'ournick'}
    init()

  afterEach ->
    removeHTMLFixtures()
    chrome.storage.sync.clear()

  it "displays the preferred nick in the status bar", ->
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
    type '/me is 1337'
    type '/op bob'
    type '/msg someguy'
    type '/mode sally +o'

  describe "sync storage", ->

    doActivity = ->
      type '/nick ournick'
      type '/server freenode 6667'
      type '/join #bash'
      type '/join #awesome'
      type '/server dalnet 6697'
      type '/win 4'
      type '/join #hiphop'

    beforeEach ->
      chrome.storage.sync.clear()
      doActivity()

    it "restores the previously used nick", ->
      restart()
      expect(client.previousNick).toBe 'ournick'

    it "restores the previously joined servers", ->
      restart()
      expect(client.connections['freenode']).toBeDefined()
      expect(client.connections['dalnet']).toBeDefined()

    it "restores the previously joined channels", ->
      restart()
      expect(client.connections['freenode'].windows['#bash']).toBeDefined()
      expect(client.connections['freenode'].windows['#awesome']).toBeDefined()
      expect(client.connections['dalnet'].windows['#hiphop']).toBeDefined()
      expect($('li', '#channels').length).toBe 5

    it "doesn't restore channels that were parted", ->
      type '/part #hiphop'
      restart()
      expect(client.connections['dalnet'].windows['#hiphop']).not.toBeDefined()
      expect($('li', '#channels').length).toBe 4

    it "doesn't restore servers that were parted", ->
      type '/win 1'
      type '/quit'
      restart()
      expect(client.connections['freenode']).not.toBeDefined()
      expect($('li', '#channels').length).toBe 2

  describe "that is connecting", ->
    irc = undefined

    beforeEach ->
      type '/server freenode'
      irc = client.currentWindow.conn.irc
      expect(irc.state).toBe 'connecting'

    it 'can queue a disconnection request with /quit', ->
      type '/quit'
      irc.handle '1', {}, 'ournick' # rpl_welcome
      expect(irc.state).toBe 'disconnected'

    it 'allows channels to be joined while connecting', ->
      type '/join #bash'
      expect($('li', '#channels').length).toBe 2
      expect($('li', '#channels').last().children()).toHaveText '(#bash)'
      expect($('li', '#channels').last()).toHaveClass 'selected'

    it 'automatically joins queued channels when connected', ->
      type '/join #bash'
      type '/part'
      spyOn irc, 'send'
      irc.handle '1', {}, 'ournick' # rpl_welcome
      expect(irc.send).not.toHaveBeenCalled()

    it 'removes queued channels on /part', ->
      type '/join #bash'
      spyOn irc, 'send'
      irc.handle '1', {}, 'ournick' # rpl_welcome
      expect(irc.send).toHaveBeenCalledWith 'JOIN', '#bash'

  describe "that connects", ->
    irc = undefined

    beforeEach ->
      type '/server freenode'
      irc = client.currentWindow.conn.irc
      irc.handle '1', {}, 'ournick' # rpl_welcome
      expect(irc.state).toBe 'connected'
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

    describe "then is disconnected by a socket error", ->

      beforeEach ->
        jasmine.Clock.useMock()
        irc.onError 'socket error!'

      it 'shows all servers and channels as disconnected', ->
        expect($('li', '#channels').children()).toHaveText '(freenode)'

      it 'attempts to reconnect after a short amount of time', ->
        spyOn(irc, 'connect')
        jasmine.Clock.tick(2000)
        expect(irc.connect).toHaveBeenCalled()

      it 'uses exponential backoff for reconnection attempts', ->
        jasmine.Clock.tick(2000)
        irc.onError 'socket error!'

        spyOn(irc, 'connect')
        jasmine.Clock.tick(2000)
        expect(irc.connect).not.toHaveBeenCalled()

        jasmine.Clock.tick(2000)
        expect(irc.connect).toHaveBeenCalled()

        irc.connect.reset()
        irc.onError 'socket error!'
        jasmine.Clock.tick(7999)
        expect(irc.connect).not.toHaveBeenCalled()

      it 'closes the current window and stops reconnecting on /quit', ->
        type "/quit"
        expect(client.currentWindow.name).toBe 'none'

        spyOn(irc, 'connect')
        jasmine.Clock.tick(9000)
        expect(irc.connect).not.toHaveBeenCalled()

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

      it "marks a window as active if a message is sent and it's not selected", ->
        type '/server dalnet'
        irc2 = client.currentWindow.conn.irc
        irc2.handle '1', {}, 'ournick' # rpl_welcome
        type '/win 3'
        type '/join #bash'
        irc.handle 'JOIN', {nick: 'ournick'}, '#bash'

        irc.handle 'PRIVMSG', {nick: 'someguy'}, '#bash', 'hi'
        expect($($('li', '#channels')[1])).toHaveClass 'activity'

      it "clears activity and mention style when switching to a window", ->
        type "/win 1"
        irc.handle 'PRIVMSG', {nick: 'someguy'}, '#bash', 'hey!'
        type "/win 2"
        expect($('li', '#channels').last()).not.toHaveClass 'mention'
        expect($('li', '#channels').last()).not.toHaveClass 'activity'
        expect($('li', '#channels').last()).toHaveClass 'selected'

      it "clicking on a channel in the channel display switches to that channel", ->
        client.channelDisplay.emit 'clicked', 'freenode', '#bash'
        expect(client.currentWindow.target).toBe '#bash'
        expect($('li', '#channels').last()).toHaveClass 'selected'

      describe "has a nick list which", ->
        nicks = undefined

        beforeEach ->
          nicks = ['bart', 'bill', 'bob', 'charlie', 'derek', 'edward', 'jacob',
              'megan', 'norman', 'sally', 'sue', 'tereza',
              'zabo1', 'zabo2', 'zabo3', 'zabo88']

        addNicks = ->
          irc.emit 'names', '#bash', nicks.slice(0, 7)
          irc.emit 'names', '#bash', nicks.slice(7, 12)
          irc.emit 'names', '#bash', nicks.slice(12)
          nameMap = {}
          (nameMap[name] = name for name in nicks)
          irc.channels['#bash'].names = nameMap

        it "displays the user's nick when first joining a channel", ->
          expect($('li', '#nicks').length).toBe 1
          expect($('li', '#nicks').children()).toHaveText 'ournick'

        it "displays all nicks in the channel when the nick list is sent", ->
          addNicks()
          expect($('li', '#nicks').length).toBe nicks.length + 1

        it "displays nicks in sorted order", ->
          addNicks()
          expect($($('li', '#nicks')[9]).children()).toHaveText 'ournick'

        it "displays newly joined nicks after they /join", ->
          addNicks()
          irc.handle 'JOIN', {nick: 'alphy'}, '#bash'
          expect($('li', '#nicks').length).toBe nicks.length + 2
          expect($($('li', '#nicks')[0]).children()).toHaveText 'alphy'

        it "doesn't display nicks after they have been kicked", ->
          addNicks()
          irc.handle 'KICK', {nick: 'bob'}, '#bash', 'zabo88'
          expect($('li', '#nicks').length).toBe nicks.length
          expect($('li', '#nicks').last().children()).not.toHaveText 'zabo88'

        it "doesn't display nicks after they left with /parted", ->
          addNicks()
          irc.handle 'PART', {nick: 'bob'}, '#bash'
          expect($('li', '#nicks').length).toBe nicks.length
          expect($($('li', '#nicks')[2]).children()).not.toHaveText 'bob'

        it "doesn't display duplicate nicks", ->
          nicks.push 'ournick'
          addNicks()
          expect($('li', '#nicks').length).toBe nicks.length
