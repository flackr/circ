describe 'An IRC client', ->
  irc = socket = chat = undefined

  waitsForArrayBufferConversion = () ->
    waitsFor (-> not window.irc.util.isConvertingArrayBuffers()),
      'wait for array buffer conversion', 50

  resetSpies = () ->
    socket.connect.reset()
    socket.received.reset()
    socket.close.reset()
    chat.onConnected.reset()
    chat.onIRCMessage.reset()
    chat.onJoined.reset()
    chat.onParted.reset()
    chat.onDisconnected.reset()

  beforeEach ->
    jasmine.Clock.useMock()
    socket = new net.MockSocket
    irc = new window.irc.IRC socket
    chat = new window.chat.MockChat irc

    spyOn(socket, 'connect')
    spyOn(socket, 'received').andCallThrough()
    spyOn(socket, 'close').andCallThrough()

    spyOn(chat, 'onConnected')
    spyOn(chat, 'onIRCMessage')
    spyOn(chat, 'onJoined')
    spyOn(chat, 'onParted')
    spyOn(chat, 'onDisconnected')

  it 'is initially disconnected', ->
    expect(irc.state).toBe 'disconnected'

  it 'does nothing on non-connection commands when disconnected', ->
    irc.quit()
    irc.giveup()
    irc.doCommand('NICK', 'sugarman')
    waitsForArrayBufferConversion()
    runs ->
      expect(irc.state).toBe 'disconnected'
      expect(socket.received).not.toHaveBeenCalled()

  describe 'that is connecting', ->

    beforeEach ->
      irc.setPreferredNick 'sugarman'
      irc.connect 'irc.freenode.net', 6667
      expect(irc.state).toBe 'connecting'
      socket.respond 'connect'
      waitsForArrayBufferConversion()

    it 'is connecting to the correct server and port', ->
      expect(socket.connect).toHaveBeenCalledWith('irc.freenode.net', 6667)

    it 'sends NICK and USER', ->
      runs ->
        expect(socket.received.callCount).toBe 2
        expect(socket.received.argsForCall[0]).toMatch /NICK sugarman\s*/
        expect(socket.received.argsForCall[1]).toMatch /USER sugarman 0 \* :.+/

    it 'appends an underscore when the desired nick is in use', ->
      socket.respondWithData ":irc.freenode.net 433 * sugarman :Nickname is already in use.\r\n"
      waitsForArrayBufferConversion()
      runs ->
        expect(socket.received.mostRecentCall.args).toMatch /NICK sugarman_\s*/

    describe 'then connects', ->

      beforeEach ->
        resetSpies()
        socket.respondWithData ":cameron.freenode.net 001 sugarman :Welcome\r\n"
        waitsForArrayBufferConversion()

      it "is in the 'connected' state", ->
        runs ->
          expect(irc.state).toBe 'connected'

      it 'emits connect', ->
        runs ->
          expect(chat.onConnected).toHaveBeenCalled()

      it 'emits join after joining a room', ->
        irc.doCommand 'JOIN', '#sugarman'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.callCount).toBe 1
          expect(socket.received.mostRecentCall.args).toMatch /JOIN #sugarman\s*/

      it "sends PRIVMSG on /say", ->
        irc.doCommand 'JOIN', '#sugarman'
        irc.doCommand 'PRIVMSG', '#sugarman', 'hello world'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.callCount).toBe 2
          expect(socket.received.mostRecentCall.args).toMatch /PRIVMSG #sugarman :hello world\s*/

      it "can join multiple channels and /say on all of them", ->
        irc.doCommand 'JOIN', '#sugarman'
        irc.doCommand 'JOIN', '#sugarman2'
        irc.doCommand 'PRIVMSG', '#sugarman', 'hello sugarman'
        irc.doCommand 'PRIVMSG', '#sugarman2', 'hello sugarman2'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.callCount).toBe 4
          expect(socket.received.argsForCall[0]).toMatch /JOIN #sugarman\s*/
          expect(socket.received.argsForCall[1]).toMatch /JOIN #sugarman2\s*/
          expect(socket.received.argsForCall[2]).toMatch /PRIVMSG #sugarman :hello sugarman\s*/
          expect(socket.received.argsForCall[3]).toMatch /PRIVMSG #sugarman2 :hello sugarman2\s*/

      it "responds to a PING with a PONG", ->
        socket.respondWithData "PING :#{(new Date()).getTime()}\r\n"
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.callCount).toBe 1
          expect(socket.received.mostRecentCall.args).toMatch /PONG \d+\s*/

      it "sends a PING after a long period of inactivity", ->
        jasmine.Clock.tick(80000)
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.callCount).toBe 1 # NICK, USER and now PING
          expect(socket.received.mostRecentCall.args).toMatch /PING \d+\s*/

      it "doesn't send a PING if regularly active", ->
        jasmine.Clock.tick(50000)
        socket.respondWithData "PING :#{(new Date()).getTime()}\r\n"
        jasmine.Clock.tick(50000)
        irc.doCommand 'JOIN', '#sugarman'
        waitsForArrayBufferConversion() # wait for JOIN
        runs ->
          jasmine.Clock.tick(50000)
          waitsForArrayBufferConversion() # wait for possible PING
          runs ->
            expect(socket.received.callCount).toBe 2

      it "can disconnected from the server on /quit", ->
        irc.doCommand 'JOIN', '#sugarman'
        irc.quit 'this is my reason'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.callCount).toBe 2
          expect(socket.received.mostRecentCall.args).toMatch /QUIT :this is my reason\s*/
          expect(irc.state).toBe 'disconnected'
          expect(socket.close).toHaveBeenCalled()
