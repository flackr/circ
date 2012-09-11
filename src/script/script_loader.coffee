exports = window.script ?= {}

class ScriptLoader
  constructor: ->

  loadIntoFrame: (sourceCode) ->
    frame = @_createIframe()
    frame.eval(sourceCode)
    frame

  _createIframe: ->
    iframe = document.createElement('iframe')
    iframe.style.display = 'none'
    document.body.appendChild(iframe)
    frames[frames.length - 1]

  loadIntoFrameFromFileSystem: ->
    chrome.fileSystem.chooseFile { type: 'openFile' }, @_onChosenFileToOpen

  _onChosenFileToOpen: (fileEntry) =>
    fileEntry.file (file) ->
      fileReader = new FileReader()

      fileReader.onload = (e) ->
        sourceCode = e.target.result
        try
          @loadIntoFrame sourceCode
        catch error
          console.error 'failed to eval:', error.toString()

      fileReader.onerror = (e) ->
        console.error 'Read failed:', e.toString()

      fileReader.readAsText file

exports.ScriptLoader = ScriptLoader