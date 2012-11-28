describe 'A window list', ->
  wl = windows = undefined

  createWindow = (server, chan) ->
    win = new chat.Window server, chan
    win.setTarget chan if chan
    win.conn = { name: server }
    windows.push win
    win

  joinMultipleServersAndChannels = ->
    wl.add createWindow 'freenode'
    wl.add createWindow 'freenode', '#bash'
    wl.add createWindow 'freenode', '#zebra'
    wl.add createWindow 'dalnet'
    wl.add createWindow 'dalnet', '#bash'
    wl.add createWindow 'dalnet', '#zebra'

  beforeEach ->
    wl = new chat.WindowList()
    windows = []

  it 'returns undefined when getChannelWindow is called with no matching window', ->
    expect(wl.getChannelWindow 0).toBeUndefined()

  it 'returns -1 when indexOf is called with no matching window', ->
    expect(wl.indexOf createWindow 'freenode').toBe -1
    expect(wl.indexOf createWindow 'freenode', '#bash').toBe -1

  it 'can have windows added', ->
    wl.add createWindow 'freenode'
    wl.add createWindow 'freenode', '#bash'

  it 'can have windows removed', ->
    wl.add createWindow 'freenode'
    wl.add createWindow 'freenode', '#bash'
    wl.remove windows[0]
    wl.remove windows[1]

  it 'throws an error when a channel window is added with no corresponding connection window', ->
    addChannelWindow = -> wl.add createWindow 'freenode', '#bash'
    expect(addChannelWindow).toThrow()

  it "returns undefined on getChannelWindow when it only has server windows", ->
    wl.add createWindow 'freenode'
    wl.add createWindow 'dalnet'
    expect(wl.getChannelWindow 0).toBeUndefined()
    expect(wl.getChannelWindow 1).toBeUndefined()

  it "returns the nth window on get(n)", ->
    joinMultipleServersAndChannels()
    for i in [0..5]
      expect(wl.get i).toBe windows[i]

  it "has a length property which is equal to the number of windows", ->
    expect(wl.length).toBe 0
    joinMultipleServersAndChannels()
    expect(wl.length).toBe 6
    wl.remove windows[0]
    expect(wl.length).toBe 3
    wl.add windows[0]
    expect(wl.length).toBe 4

  it "returns undefined when get is called on a deleted window", ->
    joinMultipleServersAndChannels()
    wl.remove windows[0]
    wl.remove windows[4]
    expect(wl.get 'freenode').toBeUndefined()
    expect(wl.get 'dalnet', '#bash').toBeUndefined()

  it "deletes all channel windows when their server window is deleted", ->
    joinMultipleServersAndChannels()
    wl.remove windows[0]
    wl.remove windows[4]
    for i, window in [-1, -1, -1, 0, -1, 1]
      expect(wl.indexOf windows[window]).toBe i

  it "returns the Nth channel window on getChannelWindow(N)", ->
    joinMultipleServersAndChannels()
    for window, i in [1, 2, 4, 5]
      expect(wl.getChannelWindow i).toBe windows[window]

  it "returns the Nth server window on getServerWindow(N)", ->
    joinMultipleServersAndChannels()
    expect(wl.getServerWindow 1).toBe windows[3]

  it "returns the server window with the given name on getServerWindow(N)", ->
    joinMultipleServersAndChannels()
    expect(wl.getServerWindow 1).toBe windows[3]

  it "returns the window with the given server and channel on get(server, chan)", ->
    joinMultipleServersAndChannels()
    expect(wl.get 'freenode').toBe windows[0]
    expect(wl.get 'freenode', '#bash').toBe windows[1]
    expect(wl.get 'freenode', '#zebra').toBe windows[2]
    expect(wl.get 'dalnet').toBe windows[3]
    expect(wl.get 'dalnet', '#bash').toBe windows[4]
    expect(wl.get 'dalnet', '#zebra').toBe windows[5]

  it "returns the index of the given window on indexOf(window)", ->
    joinMultipleServersAndChannels()
    for i in [0..5]
      expect(wl.indexOf windows[i]).toBe i

  it "sorts windows under the same server in alphabetical order by their channel", ->
    wl.add createWindow 'freenode'
    wl.add createWindow 'freenode', '#zebra'
    wl.add createWindow 'freenode', '#bash'

    for window, i in [0, 2, 1]
      expect(wl.indexOf windows[window]).toBe i

  it "sorts first by server, then by channel", ->
    wl.add createWindow 'freenode'
    wl.add createWindow 'dalnet'
    wl.add createWindow 'dalnet', '#zebra'   # windows 2
    wl.add createWindow 'freenode', '#zebra' # windows 3
    wl.add createWindow 'dalnet', '#bash'    # windows 4
    wl.add createWindow 'freenode', '#bash'  # windows 5

    for window, i in [5, 3, 4, 2]
      expect(wl.getChannelWindow i).toBe windows[window]

    for window, i in [0, 5, 3, 1, 4, 2]
      expect(wl.indexOf windows[window]).toBe i

  it "returns the window index on indexOf when it only has server windows", ->
    wl.add createWindow 'freenode'
    wl.add createWindow 'dalnet'
    expect(wl.indexOf windows[0]).toBe 0
    expect(wl.indexOf windows[1]).toBe 1

  it "returns the window on get() when it only has server windows", ->
    wl.add createWindow 'freenode'
    wl.add createWindow 'dalnet'
    expect(wl.get 'freenode').toBe windows[0]
    expect(wl.get 'dalnet').toBe windows[1]

  it "can return the index of a channel in the context of its server", ->
    wl.add createWindow 'freenode'
    wl.add createWindow 'dalnet'
    wl.add createWindow 'dalnet', '#zebra'   # windows 2
    wl.add createWindow 'freenode', '#zebra' # windows 3
    wl.add createWindow 'dalnet', '#bash'    # windows 4
    wl.add createWindow 'freenode', '#bash'  # windows 5
    expect(wl.localIndexOf windows[2]).toBe 1
    expect(wl.localIndexOf windows[5]).toBe 0

  it "can return the server that corresponds with a given window", ->
    joinMultipleServersAndChannels()
    expect(wl.getServerForWindow windows[0]).toBe windows[0]
    expect(wl.getServerForWindow windows[1]).toBe windows[0]
    expect(wl.getServerForWindow windows[2]).toBe windows[0]
    expect(wl.getServerForWindow windows[3]).toBe windows[3]
    expect(wl.getServerForWindow windows[4]).toBe windows[3]
    expect(wl.getServerForWindow windows[5]).toBe windows[3]
