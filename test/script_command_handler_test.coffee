describe 'A script command handler', ->

  beforeEach ->
    onEmit = jasmine.createSpy 'onEmit'
    sc = new window.script.ScriptCommands()
    sc.setEmitCallback onEmit

  xit "can have custom commands registered", ->

  xit "prints input on the 'input' command", ->

  xit "creates a desktop notification on the 'notify' command", ->