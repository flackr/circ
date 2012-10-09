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
      irc.handle '1', 'ournick' # rpl_welcome
      spyOn irc, 'doCommand'

    it "marks the server item in the window list as connected", ->
      expect($('li', '#channels').children()).toHaveText 'freenode'

    it "updates the status bar on /away", ->
      type '/away'
      irc.handle '306' # rpl_nowaway
      expect($ '#status').toHaveText '[ournick] (away)'

    it "can join a channel with /join", ->
      type '/join #bash'
      expect(irc.doCommand).toHaveBeenCalledWith 'JOIN', '#bash'

    describe "then joins a channel", ->

      beforeEach ->
        type '/join #bash'
        irc.emit 'joined', '#bash'
        irc.channels['#bash'] = {names:[]}

      it "adds another item to the window display", ->
        expect($('li', '#channels').length).toBe 2