describe 'A message handler', ->
  mh = mock = undefined
  onEat = jasmine.createSpy('onEat')
  onEatMore = jasmine.createSpy('onEatMore')
  onDrink = jasmine.createSpy('onDrink')
  onRun = jasmine.createSpy('onRun')

  beforeEach ->
    mh = new MessageHandler()
    mock = new test.MockMessageHandler()
    spyOn(mock._handlers, 'eat')
    spyOn(mock._handlers, 'drink')

  it 'it reports that it can handle registered messages', ->
    mh.registerHandler 'eat', onEat
    expect(mh.canHandle('eat')).toBe true

  it 'it reports that it cannot handle unregistered messages', ->
    mh.registerHandler 'eat', onEat
    expect(mh.canHandle('drink')).toBe false

  it 'can register multiple handlers', ->
    mh.registerHandler 'eat', onEat
    mh.registerHandler 'drink', onDrink
    expect(mh.canHandle('eat')).toBe true
    expect(mh.canHandle('drink')).toBe true
    expect(mh.canHandle('run')).toBe false

  it 'calls registered handler on corresponding message', ->
    mh.registerHandler 'eat', onEat
    mh.handle 'eat', 'bacon', 'pie'
    expect(onEat).toHaveBeenCalledWith 'bacon', 'pie'

  it 'does not call registered handler on non-corresponding message', ->
    mh.registerHandler 'eat', onEat
    mh.registerHandler 'drink', onDrink
    mh.handle 'eat', 'bacon', 'pie'
    expect(onDrink).not.toHaveBeenCalled()

  it 'can register multiple handlers for the same message', ->
    mh.registerHandler 'eat', onEat
    mh.registerHandler 'eat', onEatMore
    mh.handle 'eat', 'bacon', 'pie'
    expect(onEat).toHaveBeenCalledWith 'bacon', 'pie'
    expect(onEatMore).toHaveBeenCalledWith 'bacon', 'pie'

  it 'can register multiple handlers simultaneously', ->
    handlers =
      eat: onEat
      drink: onDrink
    mh.registerHandlers handlers
    mh.registerHandler 'eat', onEat
    mh.registerHandler 'drink', onDrink
    mh.handle 'eat', 'bacon', 'pie'
    mh.handle 'drink', 'water'
    expect(onEat).toHaveBeenCalledWith 'bacon', 'pie'
    expect(onDrink).toHaveBeenCalledWith 'water'

  it 'can be extended', ->
    expect(mock.canHandle('eat')).toBe true
    expect(mock.canHandle('drink')).toBe true
    expect(mock.canHandle('run')).toBe false
    mock.handle 'eat', 'bacon', 'pie'
    expect(mock._handlers.eat).toHaveBeenCalledWith 'bacon', 'pie'
    expect(mock._handlers.drink).not.toHaveBeenCalled()

  it 'can merge handlers', ->
    mh.registerHandler 'eat', onEat
    mh.registerHandler 'run', onRun
    mh.merge mock
    expect(mh.canHandle('eat')).toBe true
    expect(mh.canHandle('drink')).toBe true
    expect(mh.canHandle('run')).toBe true
    expect(mh.canHandle('fly')).toBe false
    mh.handle 'eat', 'bacon', 'pie'
    mh.handle 'drink', 'water'
    mh.handle 'run'
    expect(onEat).toHaveBeenCalledWith 'bacon', 'pie'
    expect(mock._handlers.eat).toHaveBeenCalledWith 'bacon', 'pie'
    expect(mock._handlers.drink).toHaveBeenCalledWith 'water'
    expect(onRun).toHaveBeenCalledWith()

  it 'can listen to an event emitter', ->
    emitter = new EventEmitter()
    mh.listenTo emitter
    emitter.emit 'eat', 'bacon', 'pie'
    expect(onEat).toHaveBeenCalledWith 'bacon', 'pie'
