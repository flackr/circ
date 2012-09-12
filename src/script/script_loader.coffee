exports = window.script ?= {}

class ScriptLoader
  constructor: ->
    @_frameToScriptMap = {}
    addEventListener('message', @_sendSourceCode)

  _sendSourceCode: (e) =>
    if (script = @_frameToScriptMap[e.source]) and e.data.type == 'onload'
      e.source.postMessage { type: 'script', script: script }, '*'
      delete @_frameToScriptMap[e.source]

  loadIntoFrame: (sourceCode) ->
    frame = @_createIframe()
    @_frameToScriptMap[frame] = sourceCode
    frame

  _createIframe: ->
    iframe = document.createElement('iframe')
    $(iframe).attr('src', 'script_frame.html')
    iframe.style.display = 'none'
    document.body.appendChild(iframe)
    iframe.contentWindow

  loadIntoFrameFromFileSystem: (callback) ->
    chrome.fileSystem.chooseFile { type: 'openFile' }, (f) =>
      @_onChosenFileToOpen f, callback

  _onChosenFileToOpen: (fileEntry, callback) ->
    fileEntry.file (file) =>
      fileReader = new FileReader()

      fileReader.onload = (e) =>
        sourceCode = e.target.result
        try
          frame = @loadIntoFrame sourceCode
          callback frame
        catch error
          console.error 'failed to eval:', error.toString()

      fileReader.onerror = (e) ->
        console.error 'Read failed:', e.toString()

      fileReader.readAsText file

exports.loader = new ScriptLoader()