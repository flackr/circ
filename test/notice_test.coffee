describe "A notice", ->
  notice = undefined

  getMessage = ->
    $("#notice .content")

  getOption = (index) ->
    $("#notice .option" + index)

  isVisible = ->
    $("#notice")[0].style.top is '0px'

  beforeEach ->
    mocks.dom.setUp()
    notice = new chat.Notice()

  afterEach ->
    mocks.dom.tearDown()

  it "is initially hidden", ->
    expect(isVisible()).toBe false

  it "becomes visible after prompt() is called", ->
    notice.prompt "Device detected"
    expect(isVisible()).toBe true

  it "can be manually closed with close()", ->
    notice.prompt "Device detected"
    notice.close()
    expect(isVisible()).toBe false

  it "is closed when the close button is clicked", ->
    notice.prompt "Device detected"
    $("#notice .close").click()
    expect(isVisible()).toBe false

  it "can display a message", ->
    notice.prompt 'Device detected'

    expect(getMessage()).toHaveText 'Device detected'
    expect(getOption(1)).toHaveClass 'hidden'
    expect(getOption(2)).toHaveClass 'hidden'

  it "can display a message with a clickable button", ->
    notice.prompt "Device detected [Connect]"

    expect(getMessage()).toHaveText 'Device detected'

    expect(getOption(1)).toHaveText 'Connect'
    expect(getOption(1)).not.toHaveClass 'hidden'

    expect(getOption(2)).toHaveClass 'hidden'

  it "can display a message with two clickable buttons", ->
    notice.prompt "Device detected [Connect] [?]"

    expect(getMessage()).toHaveText 'Device detected'

    expect(getOption(1)).toHaveText 'Connect'
    expect(getOption(1)).not.toHaveClass 'hidden'

    expect(getOption(2)).toHaveText '?'
    expect(getOption(2)).not.toHaveClass 'hidden'

  it "calls a specified callback function when a button is clicked", ->
    connect = jasmine.createSpy 'connect'
    help = jasmine.createSpy 'help'
    notice.prompt "Device detected [Connect] [?]", (=> connect()), (=> help())
    getOption(2).click()

    expect(help).toHaveBeenCalled()
    expect(connect).not.toHaveBeenCalled()
    expect(isVisible()).toBe false
