describe "A keyboard shortcut map", ->
  map = undefined

  beforeEach ->
    map = new KeyboardShortcutMap()

  it "maps a keyboard event to a command with certain arguments", ->
    alt1 = { altKey: true, which: 49 }
    [command, args] = map.getMappedCommand alt1
    expect(command).toBe 'win'
    expect(args).toEqual [1]

  it "returns an undefined command when the shortcut doesn't match any command", ->
    ctrl1 = { ctrlKey: true, which: 49 }
    [command, args] = map.getMappedCommand ctrl1
    expect(command).not.toBeDefined()

  it "maps Tab to a command when the input field is empty", ->
    tab = { which: 9 }
    [command, args] = map.getMappedCommand tab, ""
    expect(command).toBeDefined()

  it "doesn't map Tab to a command when the input field isn't empty", ->
    tab = { which: 9 }
    [command, args] = map.getMappedCommand tab, "user input"
    expect(command).not.toBeDefined()