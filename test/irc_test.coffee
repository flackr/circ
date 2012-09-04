describe 'An IRC client', ->
  irc = socket = chat = undefined

  waitsForArrayBufferConversion = () ->
    waitsFor (-> not irc.util.isConvertingArrayBuffers()),
      'wait for array buffer conversion', 50

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


  describe 'while connecting it', ->
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


    describe 'after connecting it', ->
      beforeEach ->
        socket.respondWithData ":cameron.freenode.net 001 sugarman :Welcome\r\n"
        waitsForArrayBufferConversion()
        runs ->
          expect(irc.state).toBe 'connected'

      it 'emits connect', ->
        runs ->
          expect(chat.onConnected).toHaveBeenCalled()

      it 'emits join after joining a room', ->
        irc.doCommand 'JOIN', '#sugarman'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.argsForCall[2]).toMatch /JOIN #sugarman\s*/

      it "sends PRIVMSG on /say", ->
        irc.doCommand 'JOIN', '#sugarman'
        irc.doCommand 'PRIVMSG', '#sugarman', 'hello world'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.argsForCall[3]).toMatch /PRIVMSG #sugarman :hello world\s*/

      it "can join multiple channels and /say on all of them", ->
        irc.doCommand 'JOIN', '#sugarman'
        irc.doCommand 'JOIN', '#sugarman2'
        irc.doCommand 'PRIVMSG', '#sugarman', 'hello sugarman'
        irc.doCommand 'PRIVMSG', '#sugarman2', 'hello sugarman2'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.argsForCall[2]).toMatch /JOIN #sugarman\s*/
          expect(socket.received.argsForCall[3]).toMatch /JOIN #sugarman2\s*/
          expect(socket.received.argsForCall[4]).toMatch /PRIVMSG #sugarman :hello sugarman\s*/
          expect(socket.received.argsForCall[5]).toMatch /PRIVMSG #sugarman2 :hello sugarman2\s*/

      it "can disconnected from the server on /quit", ->
        irc.doCommand 'JOIN', '#sugarman'
        irc.quit 'this is my reason'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.argsForCall[3]).toMatch /QUIT :this is my reason\s*/
          expect(irc.state).toBe 'disconnected'
          expect(socket.close).toHaveBeenCalled()
