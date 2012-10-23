describe 'An IRC client front end', ->
  client = prompt = commandInput = undefined

  room = (index) ->
    return rooms().last() if index is -1
    $ rooms()[index]

  rooms = ->
    $ '#rooms-container .rooms .room'

  textOfRoom = (index) ->
    $('.content-item', room(index)).text()

  nick = (index) ->
    return nicks().last() if index is -1
    $ nicks()[index]

  nicks = ->
    $ '#nicks-container .nicks .nick'

  textOfNick = (index) ->
    $('.content-item', nick(index)).text()

  device = (i) ->
    mocks.RemoteDevice.devices[i]

  irc = (name) ->
    client.connections[name]?.irc

  type = (text) ->
    prompt.val(text)
    commandInput._handleKeydown { which: 13, preventDefault: -> }

  restart = ->
    mocks.dom.tearDown()
    mocks.dom.setUp()
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
    mocks.dom.setUp()
    mocks.ChromeSocket.useMock()
    mocks.RemoteDevice.useMock()
    mocks.NickMentionedNotification.useMock()
    prompt = $('#input')
    commandInput = new UserInputHandler(prompt, $ window)
    chrome.storage.sync.set { nick: 'ournick' }
    init()

  afterEach ->
    mocks.dom.tearDown()
    chrome.storage.sync.clear()

  it "displays the preferred nick in the status bar", ->
    expect($ '#status').toHaveText 'ournick'

  it "sets the document title to the version", ->
    expect(document.title).toMatch /^CIRC [0-9].[0-9].[0-9]$/

  it "initially has one window", ->
    expect(rooms().length).toBe 1

  it "replaces the initial window with a server window on /connect", ->
    type '/connect freenode'
    expect(rooms().length).toBe 1
    expect(textOfRoom 0).toBe 'freenode'
    expect(client.currentWindow.conn.name).toBe 'freenode'

  it "ignores commands that requicre a connection not connected", ->
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

    it "chooses a new password when one doesn't currently exist", ->
      expect(client.remoteConnection._password).toEqual jasmine.any(String)

    it "keeps the old password when one exists", ->
      chrome.storage.sync.set { password: 'bob' }
      restart()
      expect(client.remoteConnection._password).toBe 'bob'

    it "restores the previously used nick", ->
      restart()
      expect($ '#status').toHaveText 'ournick'

    it "generates random nick when no previously used nick is available", ->
      chrome.storage.sync.set { nick: undefined }
      restart()
      type "/connect freenode"
      expect(irc('freenode').preferredNick).toBeDefined()

    it "restores the previously joined servers", ->
      restart()
      expect(client.connections['freenode']).toBeDefined()
      expect(client.connections['dalnet']).toBeDefined()

    it "restores the previously joined channels", ->
      restart()
      expect(client.connections['freenode'].windows['#bash']).toBeDefined()
      expect(client.connections['freenode'].windows['#awesome']).toBeDefined()
      expect(client.connections['dalnet'].windows['#hiphop']).toBeDefined()
      expect(rooms().length).toBe 5

    it "doesn't restore channels that were parted", ->
      type '/part #hiphop'
      restart()
      expect(client.connections['dalnet'].windows['#hiphop']).not.toBeDefined()
      expect(rooms().length).toBe 4

    it "doesn't restore servers that were parted", ->
      type '/win 1'
      type '/quit'
      restart()
      expect(irc 'freenode').not.toBeDefined()
      expect(rooms().length).toBe 2

  describe "that is connecting", ->

    beforeEach ->
      type '/server freenode'
      expect(irc('freenode').state).toBe 'connecting'

    it 'can queue a disconnection request with /quit', ->
      currentIRC = irc('freenode')
      type '/quit'
      currentIRC.handle '1', {}, 'ournick' # rpl_welcome
      expect(currentIRC.state).toBe 'disconnected'

    it 'allows channels to be joined while connecting', ->
      type '/join #bash'
      expect(rooms().length).toBe 2
      expect(textOfRoom -1).toBe '#bash'
      expect(room -1).toHaveClass 'selected'
      expect(room -1).toHaveClass 'disconnected'

    it 'automatically joins queued channels when connected', ->
      type '/join #bash'
      type '/part'
      spyOn irc('freenode'), 'send'
      irc('freenode').handle '1', {}, 'ournick' # rpl_welcome
      expect(irc('freenode').send).not.toHaveBeenCalled()

    it 'removes queued channels on /part', ->
      type '/join #bash'
      spyOn irc('freenode'), 'send'
      irc('freenode').handle '1', {}, 'ournick' # rpl_welcome
      expect(irc('freenode').send).toHaveBeenCalledWith 'JOIN', '#bash'

  describe "that connects", ->
    currentIRC = undefined

    beforeEach ->
      type '/server freenode'
      currentIRC = irc('freenode')
      currentIRC.handle '1', {}, 'ournick' # rpl_welcome
      expect(currentIRC.state).toBe 'connected'
      spyOn currentIRC, 'doCommand'

    it "marks the server item in the window list as connected", ->
      expect(room 0).not.toHaveClass 'disconnected'

    it "updates the status bar on /away", ->
      type '/away'
      currentIRC.handle '306' # rpl_nowaway
      expect($ '#status').toHaveText 'ournick' + 'away'

    it "creates a new window when a direct private message is received", ->
      currentIRC.handle 'PRIVMSG', {nick: 'someguy'}, 'ournick', 'hi there'
      expect(rooms().length).toBe 2
      expect(textOfRoom -1).toBe 'someguy'
      expect(room -1).toHaveClass 'mention'
      expect(room -1).toHaveClass 'activity'
      expect(room -1).not.toHaveClass 'selected'

    it "displays /msg text in the current window if there is no existing conversation window", ->
      spyOn(client.currentWindow, 'message').andCallThrough()
      type '/msg someguy hey dude'
      expect(rooms().length).toBe 1
      expect(client.currentWindow.message).toHaveBeenCalled()

    it "displays /msg text in the conversation window when it exists", ->
      currentIRC.handle 'PRIVMSG', {nick: 'someguy'}, 'ournick', 'hi there'
      spyOn(client.currentWindow, 'message').andCallThrough()
      type '/msg someguy hey dude'
      expect(client.currentWindow.message).not.toHaveBeenCalled()

    it "/msg causes the conversation window to be marked with activity", ->
      currentIRC.handle 'PRIVMSG', {nick: 'someguy'}, 'ournick', 'hi there'
      type '/win 2'
      type '/win 1'
      expect(room -1).not.toHaveClass 'mention'
      expect(room -1).not.toHaveClass 'activity'
      expect(room -1).not.toHaveClass 'selected'

      type '/msg someguy hey dude'
      expect(room -1).not.toHaveClass 'mention'
      expect(room -1).toHaveClass 'activity'
      expect(room -1).not.toHaveClass 'selected'

    it "creates a notification when a direct private message is received", ->
      chat.NickMentionedNotification.notificationCount = 0
      currentIRC.handle 'PRIVMSG', {nick: 'someguy'}, 'ournick', 'hey!'
      expect(chat.NickMentionedNotification.notificationCount).toBe 1

    it "can join a channel with /join", ->
      type '/join #bash'
      expect(currentIRC.doCommand).toHaveBeenCalledWith 'JOIN', '#bash'
      expect(client.currentWindow.target).toBe '#bash'

    describe "then is disconnected by a socket error", ->

      beforeEach ->
        jasmine.Clock.useMock()
        currentIRC.onError 'socket error!'

      it 'shows all servers and channels as disconnected', ->
        expect(room 0).toHaveClass 'disconnected'

      it 'attempts to reconnect after a short amount of time', ->
        spyOn(currentIRC, 'connect')
        jasmine.Clock.tick(2000)
        expect(currentIRC.connect).toHaveBeenCalled()

      it 'uses exponential backoff for reconnection attempts', ->
        jasmine.Clock.tick(2000)
        currentIRC.onError 'socket error!'

        spyOn(currentIRC, 'connect')
        jasmine.Clock.tick(2000)
        expect(currentIRC.connect).not.toHaveBeenCalled()

        jasmine.Clock.tick(2000)
        expect(currentIRC.connect).toHaveBeenCalled()

        currentIRC.connect.reset()
        currentIRC.onError 'socket error!'
        jasmine.Clock.tick(7999)
        expect(currentIRC.connect).not.toHaveBeenCalled()

      it 'closes the current window and stops reconnecting on /quit', ->
        type "/quit"
        expect(client.currentWindow.name).toBe 'none'

        spyOn(currentIRC, 'connect')
        jasmine.Clock.tick(9000)
        expect(currentIRC.connect).not.toHaveBeenCalled()

    describe "then joins a channel", ->

      beforeEach ->
        type '/join #bash'
        currentIRC.handle 'JOIN', {nick: 'ournick'}, '#bash'

      it "adds another item to the room display", ->
        expect(rooms().length).toBe 2

      it "can switch windows with /win", ->
        type "/win 1"
        expect(client.currentWindow.target).toBe undefined

      it "creates a notification when the users nick is mentioned", ->
        type "/win 1"
        chat.NickMentionedNotification.notificationCount = 0
        currentIRC.handle 'PRIVMSG', {nick: 'someguy'}, '#bash', 'hey ournick!'
        expect(chat.NickMentionedNotification.notificationCount).toBe 1
        expect(room -1).toHaveClass 'mention'
        expect(room -1).toHaveClass 'activity'
        expect(room -1).not.toHaveClass 'selected'

      it "marks a window as active if a message is sent and it's not selected", ->
        type '/server dalnet'
        irc2 = client.currentWindow.conn.irc
        irc2.handle '1', {}, 'ournick' # rpl_welcome
        type '/win 3'
        type '/join #bash'
        currentIRC.handle 'JOIN', {nick: 'ournick'}, '#bash'

        currentIRC.handle 'PRIVMSG', {nick: 'someguy'}, '#bash', 'hi'
        expect(room 1).toHaveClass 'activity'

      it "clears activity and mention style when switching to a window", ->
        type "/win 1"
        currentIRC.handle 'PRIVMSG', {nick: 'someguy'}, '#bash', 'hey!'
        type "/win 2"
        expect(room -1).not.toHaveClass 'mention'
        expect(room -1).not.toHaveClass 'activity'
        expect(room -1).toHaveClass 'selected'

      it "clicking on a channel in the channel display switches to that channel", ->
        client.channelDisplay.emit 'clicked', 'freenode', '#bash'
        expect(client.currentWindow.target).toBe '#bash'
        expect(room -1).toHaveClass 'selected'

      describe "has a nick list which", ->
        currentNicks = undefined

        beforeEach ->
          currentNicks = ['bart', 'bill', 'bob', 'charlie', 'derek', 'edward', 'jacob',
              'megan', 'norman', 'sally', 'sue', 'Tereza',
              'zabo1', 'ZABO2', 'zabo3', 'Zabo88']

        addNicks = ->
          currentIRC.emit 'names', '#bash', currentNicks.slice(0, 7)
          currentIRC.emit 'names', '#bash', currentNicks.slice(7, 12)
          currentIRC.emit 'names', '#bash', currentNicks.slice(12)
          nameMap = {}
          (nameMap[name] = name for name in currentNicks)
          currentIRC.channels['#bash'].names = nameMap

        it "displays the user's nick when first joining a channel", ->
          expect(nicks().length).toBe 1
          expect(textOfNick 0).toBe 'ournick'

        it "displays all nicks in the channel when the nick list is sent", ->
          addNicks()
          expect(nicks().length).toBe currentNicks.length + 1

        it "displays nicks in sorted order", ->
          addNicks()
          expect(textOfNick 9).toBe 'ournick'

        it "displays newly joined nicks after they /join", ->
          addNicks()
          currentIRC.handle 'JOIN', {nick: 'alphy'}, '#bash'
          expect(nicks().length).toBe currentNicks.length + 2
          expect(textOfNick 0).toBe 'alphy'

        it "doesn't display nicks after they have been kicked", ->
          addNicks()
          currentIRC.handle 'KICK', {nick: 'bob'}, '#bash', 'Zabo88'
          expect(nicks().length).toBe currentNicks.length
          expect(textOfNick 0).not.toBe 'Zabo88'

        it "doesn't display nicks after they left with /parted", ->
          addNicks()
          currentIRC.handle 'PART', {nick: 'bob'}, '#bash'
          expect(nicks().length).toBe currentNicks.length
          expect(textOfNick 2).not.toBe 'bob'

        it "doesn't display duplicate nicks", ->
          currentNicks.push 'ournick'
          addNicks()
          expect(nicks().length).toBe currentNicks.length

        it "stays visible when another non-selected window is closed", ->
          type "/join #awesome"
          event = new Event 'command', 'part'
          event.setContext 'freenode', '#bash'
          client.userCommands.handle 'part', event
          expect($ '#rooms-and-nicks').not.toHaveClass 'no-nicks'

      describe "with a remote connection", ->
        state = onAuth = undefined

        getChannels = ->
          { '#bash': { names: { sally: 'Sally', bob: 'bob', somenick: 'somenick' } } }

        getState = ->
          nick: 'preferredNick'
          servers: [ { name: 'freenode', port: 6667 }, { name: 'dalnet', port: 6697 } ]
          channels: [ { name: '#bash', server: 'freenode' }, { name: '#awesome', server: 'dalnet' } ]
          ircStates: [ { server: 'freenode', state: 'connected', nick: 'somenick', away: true, channels: getChannels() } ]

        beforeEach ->
          state = getState()
          onAuth = spyOn mocks.RemoteDevice, 'sendAuthentication'

        afterEach ->
          mocks.RemoteDevice.reset()

        it "sends authentication when first connected to the server", ->
          type "/join-server 1.1.1.2 1336"
          expect(onAuth).toHaveBeenCalledWith jasmine.any(String)

        it "becomes a client after receiving IRC state", ->
          type "/join-server 1.1.1.2 1336"
          expect(client.remoteConnection.isServer()).toBe true
          (device 1).emit 'connection_message', 'irc_state', []
          expect(client.remoteConnection.isServer()).toBe false

        it "doesn't add a client before the client is authenticated", ->
          RemoteDevice.onNewDevice new RemoteDevice 1
          expect(client.remoteConnection.devices[0]).not.toBeDefined()

        it "add a client after it authenticates", ->
          RemoteDevice.onNewDevice new RemoteDevice 1
          expect(client.remoteConnection.devices[0]).not.toBeDefined()
          device(1).emit 'authenticate', client.remoteConnection._getAuthToken '1.1.1.1'
          expect(client.remoteConnection.devices[0]).toBeDefined()

        it "disconnects from the current connection before using the server device's connection", ->
          type "/join-server 1.1.1.2 1336"
          (device 1).emit 'connection_message', 'irc_state', []
          expect(rooms().length).toBe 1
          expect(client.connections['freenode']).not.toBeDefined()

        it "can load the IRC state from the server device", ->
          type "/join-server 1.1.1.2 1336"
          (device 1).emit 'connection_message', 'irc_state', state

          expect(rooms().length).toBe 4
          expect(irc('freenode').state).toBe 'connected'
          expect(irc('dalnet').state).toBe 'disconnected'
          expect(room 0).not.toHaveClass 'disconnected'
          expect(room 1).not.toHaveClass 'disconnected'
          expect(room 2).toHaveClass 'disconnected'
          expect(room 3).toHaveClass 'disconnected'

          type '/win 2'
          for name, i in ['bob', 'Sally', 'somenick']
            expect(textOfNick i).toBe name
          expect($('#status').text()).toBe 'somenick' + 'away'

        it "doesn't set the irc nick if the nick isn't saved", ->
          type "/join-server 1.1.1.2 1336"
          state.ircStates[0].nick = undefined
          state.nick = undefined
          (device 0).emit 'connection_message', 'irc_state', state
          expect(irc('freenode').preferredNick).toBeDefined()

        it "can listen to user input from the server device", ->
          type "/join-server 1.1.1.2 1336"
          (device 1).emit 'connection_message', 'irc_state', state
          event = new Event 'command', 'nick', 'newnick'
          event.setContext 'freenode'
          spyOn client, 'setNick'
          (device 1).emit 'user_input', event
          expect(client.setNick).toHaveBeenCalledWith 'freenode', 'newnick'

        it "can listen to socket data from the server device", ->
          type "/join-server 1.1.1.2 1336"
          (device 1).emit 'connection_message', 'irc_state', state
          spyOn irc('freenode'), 'onDrain'
          (device 1).emit 'socket_data', 'freenode', 'drain'
          expect(irc('freenode').onDrain).toHaveBeenCalled()

        it "becomes a server again after connection to the server is lost", ->
          type "/join-server 1.1.1.2 1336"
          (device 1).emit 'connection_message', 'irc_state', []
          spyOn client, 'closeAllConnections'
          (device 1).emit 'closed'
          expect(client.remoteConnection.isServer()).toBe true
          expect(client.closeAllConnections).toHaveBeenCalled()
