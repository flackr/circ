describe "A timer", ->
  timer = currentTime = undefined

  tick = (time) ->
    currentTime += time

  beforeEach ->
    currentTime = 3498573498
    timer = new Timer()
    timer._getCurrentTime = -> currentTime

  it "displays the elapsed time between two events", ->
    timer.start 'run'
    tick 23894
    time = timer.elapsed 'run'
    expect(time).toBe 23894

    tick 6
    time = timer.finish 'run'
    expect(time).toBe 23900

  it "clears previous entry when start is called multiple times", ->
    timer.start 'run'
    tick 23894
    timer.start 'run'
    tick 26
    time = timer.finish 'run'
    expect(time).toBe 26