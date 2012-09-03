describe "A disconnected IRC client", ->
  irc = socket = undefined

  freenode = 'irc.freenode.net'
  port = 6667

  beforeEach ->
    socket = new net.MockSocket
    irc = new window.irc.IRC socket

    spyOn(socket, 'connect').andCallThrough()
    spyOn(socket, 'write').andCallThrough()

  it "is initially disconnected", ->
    expect(irc.state).toBe "disconnected"

  it "does nothing on non-connection commands", ->
    irc.quit()
    irc.giveup()
    irc.doCommand('NICK', 'sugarman')
    expect(irc.state).toBe "disconnected"
    expect(socket.write).not.toHaveBeenCalled()

  it "is connecting to the correct server on connect", ->
    irc.connect(freenode, port)
    expect(irc.state).toBe "connecting"
    expect(socket.connect).toHaveBeenCalledWith(freenode, port)

  describe "A connected IRC client", ->

      beforeEach ->
        irc.connect freenode, port
