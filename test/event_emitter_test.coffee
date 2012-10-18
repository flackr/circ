describe "An event emitter", ->
  emitter = undefined

  beforeEach ->
    emitter = new EventEmitter

  it "emits events to registered listeners", ->
    onEat = jasmine.createSpy 'onEat'
    emitter.on 'eat', onEat
    emitter.emit 'eat', 'burgers'
    expect(onEat).toHaveBeenCalledWith 'burgers'

  it "doesn't emits events to non-registered listeners", ->
    onEat = jasmine.createSpy 'onEat'
    emitter.on 'eat', onEat
    emitter.emit 'cook', 'burgers'
    expect(onEat).not.toHaveBeenCalledWith 'burgers'

  it "can be listened to for any event", ->
    onAny = jasmine.createSpy 'onAny'
    emitter.onAny onAny
    emitter.emit 'drink', 'water'
    emitter.emit 'eat', 'burgers'
    expect(onAny).toHaveBeenCalledWith 'water'
    expect(onAny).toHaveBeenCalledWith 'burgers'