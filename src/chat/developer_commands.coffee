exports = window.chat ?= {}

class DeveloperCommands extends MessageHandler
  constructor: (source) ->
    super source
    @registerHandlers @_developerCommands

  _developerCommands:
    1: ->
      @onTextInput "/server irc.corp.google.com"

    2: ->
      @onTextInput "/nick sugarman#{Math.floor(Math.random() * 100)}"

    3: ->
      @onTextInput "/join #sugarman"

    4: ->
      @onTextInput "hello thar #{irc.util.randomName()}!"

    5: ->
      @onTextInput "/join #sugarman2"

    6: ->
      @onTextInput "/say Hey #{irc.util.randomName()}!"

    7: ->
      @onTextInput "/server irc.freenode.net"

    8: ->
      @onTextInput "/win 0"
      @onTextInput "/join #sugarman"

    q: ->
      @onTextInput "/quit quitting a server"

    q1: ->
      @onTextInput "/win 1"
      @onTextInput "/quit quitting a sever in window 1"

    n: ->
      new chat.Notification('test', 'hi!').show()

    o1: ->
      addIFrame()

    o2: ->
      chrome.fileSystem.chooseFile { type: 'openFile' }, onChosenFileToOpen

addIFrame = () ->
  addEventListener('message', (e) ->
    console.log 'Got response!', e.origin, e.data, e.source
  , false)

  iframe = document.createElement('iframe')
  iframe.style.display = 'none'
  document.body.appendChild(iframe)
  f = frames[frames.length - 1]
  f.addEventListener('message', (e) ->
    e.source.postMessage('here is your data ' + e.data, '*')
  , false)

safeEval = (js) ->
  f = frames[frames.length - 1]
  f.postMessage(js, '*')

onChosenFileToOpen = (fileEntry) ->
  fileEntry.file (file) ->
    fileReader = new FileReader()

    fileReader.onload = (e) ->
      js = e.target.result
      try
        safeEval(js)
      catch error
        console.error 'failed to eval:', error.toString()

    fileReader.onerror = (e) ->
      console.error 'Read failed:', e.toString()

    fileReader.readAsText file

exports.DeveloperCommands = DeveloperCommands