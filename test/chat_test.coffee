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

  noticeIsVisible = ->
    $("#notice")[0].style.top is "0px"

  restart = ->
    RemoteDevice.devices = []
    mocks.dom.tearDown()
    client.tearDown()
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
    mocks.navigator.useMock()
    mocks.ChromeSocket.useMock()
    mocks.RemoteDevice.useMock()
    mocks.NickMentionedNotification.useMock()
    jasmine.Clock.useMock()
    mocks.dom.setUp()
    prompt = $('#input')
    commandInput = new UserInputHandler(prompt, $ window)
    chrome.storage.sync.set { nick: 'ournick' }
    init()

  afterEach ->
    mocks.dom.tearDown()
    chrome.storage.sync.clear()
    client.tearDown()

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

  it "displays a prompt internet connectivity is lost", ->
    expect(noticeIsVisible()).toBe false
    mocks.navigator.goOffline()
    expect(noticeIsVisible()).toBe true

  describe "storage", ->

    doActivity = ->
      type '/nick newNick'
      type '/server freenode 6667'
      type '/join #bash'
      type '/join #awesome'
      type '/server dalnet 6697'
      type '/win 4'
      type '/join #hiphop'

    beforeEach ->
      doActivity()

    it "chooses a new password when one doesn't currently exist", ->
      expect(client.remoteConnection._password).toEqual jasmine.any(String)

    it "keeps the old password when one exists", ->
      chrome.storage.sync.set { password: 'bob' }
      restart()
      expect(client.remoteConnection._password).toBe 'bob'

    it "restores the previously used nick", ->
      restart()
      expect($ '#status').toHaveText 'newNick'

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

    it "displays restored private channels as connected", ->
      irc('freenode').handle '1', {}, 'ournick' # rpl_welcome
      irc('freenode').handle 'PRIVMSG', {nick: 'someguy'}, 'ournick', 'hi there'
      restart()
      expect(rooms().length).toBe 6
      expect(textOfRoom 3).toBe 'someguy'
      expect(room 3).not.toHaveClass 'disconnected'

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
        currentIRC.onClose()


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

        currentIRC.connect.reset() # reset the connect function spy
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

        findPort = ->
          d = client.remoteConnection._thisDevice
          d.port = 1
          RemoteDevice.state = 'found_port'
          d.emit 'found_port'

        authenticate = (device) ->
          authToken = client.remoteConnection._getAuthToken device.password
          device.emit 'authenticate', device, authToken

        receivePassword = (device, password) ->
          device.emit 'authentication_offer', device, password

        becomeClient = (opt_state) ->
          state = opt_state if opt_state
          (device 1).emit 'connection_message', device(1), 'irc_state', state

        receiveChatHistory = (chatHistory) ->
          device(1).emit 'connection_message', device(1), 'chat_log', chatHistory

        beforeEach ->
          state = getState()
          spyOn(mocks.RemoteDevice, 'onConnect').andCallThrough()

        it "connects to a server device with /join-server", ->
          type "/join-server 1.1.1.2 1336"
          expect(mocks.RemoteDevice.onConnect).toHaveBeenCalled()

        it "emits 'server_found' when server sends a password", ->
          type "/join-server 1.1.1.2 1336"
          spyOn client.remoteConnection, 'emit'
          receivePassword device(1), 'pw'
          expect(client.remoteConnection.emit).toHaveBeenCalledWith 'server_found', device(1)

        it "sends authentication after server sends a password and finalizeConnection() is called", ->
          type "/join-server 1.1.1.2 1336"
          receivePassword device(1), 'pw'
          expect(device(1).sendType).toBe 'authenticate'

        it "becomes a client after receiving IRC state", ->
          type "/join-server 1.1.1.2 1336"
          expect(client.remoteConnection.isClient()).toBe false
          becomeClient []
          expect(client.remoteConnection.isClient()).toBe true

        it "doesn't add a client before authentication", ->
          RemoteDevice.onNewDevice new RemoteDevice
          expect(client.remoteConnection.devices[0]).not.toBeDefined()

        it "add a client after it authenticates", ->
          RemoteDevice.onNewDevice new RemoteDevice
          expect(client.remoteConnection.devices[0]).not.toBeDefined()
          authenticate device 1
          expect(client.remoteConnection.devices[0]).toBeDefined()

        it "disconnects from the current connection before using the server device's connection", ->
          type "/join-server 1.1.1.2 1336"
          becomeClient []
          expect(rooms().length).toBe 1
          expect(client.connections['freenode']).not.toBeDefined()

        it "can load the IRC state from the server device", ->
          type "/join-server 1.1.1.2 1336"
          becomeClient()

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
          becomeClient()
          expect(irc('freenode').preferredNick).toBeDefined()

        it "can listen to user input from the server device", ->
          type "/join-server 1.1.1.2 1336"
          becomeClient()
          event = new Event 'command', 'nick', 'newnick'
          event.setContext 'freenode'
          spyOn client, 'setNick'
          (device 1).emit 'user_input', device(1), event
          expect(client.setNick).toHaveBeenCalledWith 'freenode', 'newnick'

        it "can listen to socket data from the server device", ->
          type "/join-server 1.1.1.2 1336"
          becomeClient()
          spyOn irc('freenode'), 'onDrain'
          (device 1).emit 'socket_data', device(1), 'freenode', 'drain'
          expect(irc('freenode').onDrain).toHaveBeenCalled()

        it "uses own connection after connection to the server is lost", ->
          type "/join-server 1.1.1.2 1336"
          becomeClient []
          spyOn client, 'closeAllConnections'
          (device 1).emit 'closed', device(1)
          expect(client.remoteConnection.isIdle()).toBe true
          expect(client.closeAllConnections).toHaveBeenCalled()

        it "on startup, when server exists, uses own connection after waiting a brief time", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          delete state.ircState
          chrome.storage.sync.set state
          restart()
          expect(rooms().length).toBe 1
          jasmine.Clock.tick(2000)
          expect(rooms().length).toBe 4

        it "automatically connects if an existing server is present", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          restart()
          expect(mocks.RemoteDevice.onConnect).toHaveBeenCalled()

        it "becomes server if storage marks it as the server device", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.1', port: 1 } }
          restart()
          findPort()
          expect(client.remoteConnection.isServer()).toBe true

        it "updates stored server device info when the server device's port changes", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.1', port: 2 } }
          restart()
          findPort()
          expect(client.remoteConnection.isServer()).toBe true
          expect(chrome.storage.sync._storageMap.server_device.port).toBe 1

        it "becomes idle if can't connect to server device", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          restart()
          expect(client.remoteConnection.getState()).toBe 'connecting'

          mocks.RemoteDevice.willConnect = false
          restart()
          expect(client.remoteConnection.isIdle()).toBe true

        it "keeps trying to connect to the server device", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          restart()
          mocks.RemoteDevice.willConnect = false
          restart()
          mocks.RemoteDevice.willConnect = true
          jasmine.Clock.tick(1000)
          expect(client.remoteConnection.getState()).toBe 'connecting'

        it "forwards user input to connected clients when acting as the server device", ->
          findPort()
          type '/make-server'
          RemoteDevice.onNewDevice new RemoteDevice
          authenticate device 1
          RemoteDevice.onNewDevice new RemoteDevice
          authenticate device 2
          expect(client.remoteConnection.devices.length).toBe 2

          spyOn device(1), 'send'
          spyOn device(2), 'send'
          spyOn client.remoteConnection, 'emit'
          device(1).emit 'user_input', device(1), {
              type: 'command', name: 'say', args: ['hi guys'],
              context: { server: 'freenode', channel: '#bash' } }
          expect(device(1).send).not.toHaveBeenCalled()
          expect(device(2).send.mostRecentCall.args[0]).toBe 'user_input'
          expect(client.remoteConnection.emit).toHaveBeenCalledWith 'command',
              jasmine.any(Event)

        it "only sends IRC state to the connecting device, not all devices", ->
          findPort()
          type '/make-server'
          RemoteDevice.onNewDevice new RemoteDevice
          authenticate device 1
          RemoteDevice.onNewDevice new RemoteDevice
          spyOn device(1), 'send'
          spyOn device(2), 'send'
          authenticate device 2
          expect(device(2).send).toHaveBeenCalled()
          expect(device(1).send).not.toHaveBeenCalled()

        it "retains connections after /make-server", ->
          findPort()
          expect(rooms().length).toBe 2
          type "/make-server"
          expect(rooms().length).toBe 2

        it "is able to connect to servers even if chrome.socket.listen isn't supported", ->
          chrome.socket.listen = undefined
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          restart()
          expect(client.remoteConnection.getState()).toBe 'connecting'

        it "can't become a server if chrome.socket.listen isn't defined", ->
          chrome.socket.listen = undefined
          type "/make-server"
          expect(client.remoteConnection.isIdle()).toBe true

        it "sends chat history when a client connects", ->
          findPort()
          type "/make-server"
          RemoteDevice.onNewDevice new RemoteDevice
          spyOn device(1), 'send'
          type 'hi there'
          authenticate device 1
          expect(device(1).send).toHaveBeenCalledWith 'connection_message',
              ['chat_log', jasmine.any(Object)]

        it "replays received chat history after connecting to a server device", ->
          type 'hi there'
          type 'i am recording some chat history'
          chatHistory = client.messageHandler.getChatLog()

          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          restart()

          becomeClient()
          win = client.winList.get('freenode', '#bash')
          spyOn win, 'rawMessage'
          receiveChatHistory chatHistory

          expect(client.remoteConnection.isClient()).toBe true
          expect(win.rawMessage).toHaveBeenCalled()

        it "connects to a server even when the server connection takes a long time", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          delete state.ircState
          chrome.storage.sync.set state
          restart()

          jasmine.Clock.tick(900) # now using own connection
          spyOn(client.remoteConnection, 'finalizeConnection').andCallThrough()
          receivePassword device(1), 'pw'
          expect(client.remoteConnection.finalizeConnection).toHaveBeenCalled()
          expect(client.remoteConnection.getState()).toBe 'connecting'

        it "displays a prompt when connecting to the server device would be abrupt", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          delete state.ircState
          chrome.storage.sync.set state
          restart()

          client.remoteConnectionHandler._timer.elapsed = -> 5000
          jasmine.Clock.tick(5000) # been using own connection for a while now
          spyOn client.remoteConnection, 'finalizeConnection'
          receivePassword device(1), 'pw'

          expect(client.remoteConnection.finalizeConnection).not.toHaveBeenCalled()
          expect(noticeIsVisible()).toBe true

        it "closes sockets when internect connection is lost", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          delete state.ircState
          chrome.storage.sync.set state
          restart()

          becomeClient()
          spyOn device(1), 'close'
          mocks.navigator.goOffline()
          expect(noticeIsVisible()).toBe true
          expect(device(1).close).toHaveBeenCalled()

        it "establishes connection when internet is renabled", ->
          chrome.storage.sync.set { server_device:  { addr: '1.1.1.2', port: 1 } }
          delete state.ircState
          chrome.storage.sync.set state
          restart()

          becomeClient()
          mocks.navigator.goOffline()
          expect(client.remoteConnection.getState()).not.toBe 'connecting'
          expect(noticeIsVisible()).toBe true
          mocks.navigator.goOnline()
          expect(client.remoteConnection.getState()).toBe 'connecting'
