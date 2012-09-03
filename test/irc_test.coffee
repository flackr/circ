describe "IRC", ->
  irc = undefined

  beforeEach ->
    irc = new window.irc.IRC new net.MockSocket

  it "is initially disconnected", ->
    expect(irc.state).toBe "disconnected"

  it "does nothing when quit while disconnected", ->
    expect(irc.quit()).not.toThrow