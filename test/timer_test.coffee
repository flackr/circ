describe "A timer", ->
  currentTime = 0

  tick = (time) ->
    currentTime += time

  beforeEach ->
    timer._getCurrentTime = -> currentTime

  it "displays the ellapsed time between two events", ->
    timer.start this, 'run'
    tick 23894
    time = timer.finish this, 'run'
    expect(time).toBe 23894