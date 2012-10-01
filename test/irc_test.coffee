describe 'An IRC client', ->
  SERVER_WINDOW = window.chat.SERVER_WINDOW
  CURRENT_WINDOW = window.chat.CURRENT_WINDOW
  irc = socket = chat = undefined

  waitsForArrayBufferConversion = () ->
    waitsFor (-> not window.irc.util.isConvertingArrayBuffers()),
      'wait for array buffer conversion', 500

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
    irc.doCommand 'NICK', 'ournick'
    waitsForArrayBufferConversion()
    runs ->
      expect(irc.state).toBe 'disconnected'
      expect(socket.received).not.toHaveBeenCalled()

  describe 'that is connecting', ->

    beforeEach ->
      irc.setPreferredNick 'ournick'
      irc.connect 'irc.freenode.net', 6667
      expect(irc.state).toBe 'connecting'
      socket.respond 'connect'
      waitsForArrayBufferConversion()

    it 'is connecting to the correct server and port', ->
      expect(socket.connect).toHaveBeenCalledWith('irc.freenode.net', 6667)

    it 'sends NICK and USER', ->
      runs ->
        expect(socket.received.callCount).toBe 2
        expect(socket.received.argsForCall[0]).toMatch /NICK ournick\s*/
        expect(socket.received.argsForCall[1]).toMatch /USER ournick 0 \* :.+/

    it 'appends an underscore when the desired nick is in use', ->
      socket.respondWithData ":irc.freenode.net 433 * ournick :Nickname is already in use."
      waitsForArrayBufferConversion()
      runs ->
        expect(socket.received.mostRecentCall.args).toMatch /NICK ournick_\s*/

    describe 'then connects', ->

      joinChannel = (chan, nick='ournick') ->
        socket.respondWithData ":#{nick}!ournick@company.com JOIN :#{chan}"
        waitsForArrayBufferConversion()

      beforeEach ->
        resetSpies()
        socket.respondWithData ":cameron.freenode.net 001 ournick :Welcome"
        waitsForArrayBufferConversion()

      it "is in the 'connected' state", ->
        runs ->
          expect(irc.state).toBe 'connected'

      it 'emits connect', ->
        runs ->
          expect(chat.onConnected).toHaveBeenCalled()

      it 'emits a welcome message', ->
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith SERVER_WINDOW, 'welcome', 'Welcome'

      it "properly creates commands on doCommand()", ->
        irc.doCommand 'JOIN', '#awesome'
        irc.doCommand 'PRIVMSG', '#awesome', 'hello world'
        irc.doCommand 'NICK', 'ournick'
        irc.doCommand 'PART', '#awesome', 'this channel is not awesome'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.callCount).toBe 4
          expect(socket.received.argsForCall[0]).toMatch /JOIN #awesome\s*/
          expect(socket.received.argsForCall[1]).toMatch /PRIVMSG #awesome :hello world\s*/
          expect(socket.received.argsForCall[2]).toMatch /NICK ournick\s*/
          expect(socket.received.argsForCall[3]).toMatch /PART #awesome :this channel is not awesome\s*/

      it "emits 'join' after joining a room", ->
        joinChannel('#awesome')
        runs ->
          expect(chat.onJoined).toHaveBeenCalled()

      it "emits a message when someone else joins a room", ->
        joinChannel '#awesome'
        joinChannel '#awesome', 'bill'
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith '#awesome', 'join', 'bill'

      it "responds to a PING with a PONG", ->
        socket.respondWithData "PING :#{(new Date()).getTime()}"
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
        socket.respondWithData "PING :#{(new Date()).getTime()}"
        jasmine.Clock.tick(50000)
        irc.doCommand 'JOIN', '#awesome'
        waitsForArrayBufferConversion() # wait for JOIN
        runs ->
          jasmine.Clock.tick(50000)
          waitsForArrayBufferConversion() # wait for possible PING
          runs ->
            expect(socket.received.callCount).toBe 2

      it "can disconnected from the server on /quit", ->
        irc.quit 'this is my reason'
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.callCount).toBe 1
          expect(socket.received.mostRecentCall.args).toMatch /QUIT :this is my reason\s*/
          expect(irc.state).toBe 'disconnected'
          expect(socket.close).toHaveBeenCalled()

      it "emits 'topic' after someone sets the topic", ->
        joinChannel '#awesome'
        socket.respondWithData ":ournick_i!~ournick@09-stuff.company.com TOPIC #awesome :I am setting the topic!"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith '#awesome', 'topic', 'ournick_i',
              'I am setting the topic!'

      it "emits 'topic' after joining a room with a topic", ->
        joinChannel '#awesome'
        socket.respondWithData ":freenode.net 332 ournick #awesome :I am setting the topic!"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith '#awesome', 'topic', undefined,
              'I am setting the topic!'

      it "emits 'topic' with no topic argument after receiving rpl_notopic", ->
        joinChannel '#awesome'
        socket.respondWithData ":freenode.net 331 ournick #awesome :No topic is set."
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith '#awesome', 'topic', undefined, undefined

      it "emits a 'kick' message when receives KICK for someone else", ->
        joinChannel '#awesome'
        socket.respondWithData ":jerk!user@65.93.146.49 KICK #awesome someguy :just cause"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith '#awesome', 'kick',
              'jerk', 'someguy', 'just cause'

      it "emits 'part' and a 'kick' message when receives KICK for self", ->
        joinChannel '#awesome'
        socket.respondWithData ":jerk!user@65.93.146.49 KICK #awesome ournick :just cause"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith '#awesome', 'kick',
              'jerk', 'ournick', 'just cause'
          expect(chat.onParted).toHaveBeenCalledWith '#awesome'

      it "emits an error notice with the given message when doing a command without privilege", ->
        joinChannel '#awesome'
        socket.respondWithData ":freenode.net 482 ournick #awesome :You're not a channel operator"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith '#awesome', 'error',
              "You're not a channel operator"

      it "emits a mode notice when someone is given channel operator status", ->
        joinChannel '#awesome'
        socket.respondWithData ":nice_guy!nice@guy.com MODE #awesome +o ournick"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith '#awesome', 'mode', 'nice_guy',
              'ournick', '+o'

      it "emits a nick notice to the server window when user's nick is changed", ->
        socket.respondWithData ":ournick!user@company.com NICK :newnick"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith SERVER_WINDOW, 'nick',
              'ournick', 'newnick'

      it "doesn't try to set nick name to own nick name on 'nick in use' message", ->
        irc.doCommand 'NICK', 'ournick_'
        socket.respondWithData "ournick!user@company.com NICK :ournick_"
        irc.doCommand 'NICK', 'ournick'
        data = ":irc.freenode.net 433 * ournick_ ournick :Nickname is already in use."
        socket.respondWithData data
        waitsForArrayBufferConversion()
        runs ->
          expect(socket.received.mostRecentCall.args).toMatch /NICK ournick__\s*/

      it "emits a privmsg notice when a private message is received", ->
        socket.respondWithData ":someguy!user@company.com PRIVMSG #awesome :hi!"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith '#awesome', 'privmsg', 'someguy', 'hi!'

      it "emits a privmsg notice when a direct message is received", ->
        socket.respondWithData ":someguy!user@company.com PRIVMSG ournick :hi!"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith 'ournick', 'privmsg', 'someguy', 'hi!'

      it "emits a privmsg notice when a busy message is received", ->
        socket.respondWithData ":server@freenode.net 301 ournick someguy :I'm busy"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith 'ournick', 'privmsg',
              'someguy', "I'm busy"

      it "emits a away notice when the user is no longer away", ->
        socket.respondWithData ":server@freenode.net 305 ournick :Not away"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith CURRENT_WINDOW, 'away', 'Not away'

      it "emits a away notice when the user is now away", ->
        socket.respondWithData ":server@freenode.net 306 ournick :Now away"
        waitsForArrayBufferConversion()
        runs ->
          expect(chat.onIRCMessage).toHaveBeenCalledWith CURRENT_WINDOW, 'away', 'Now away'