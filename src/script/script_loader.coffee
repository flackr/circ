exports = window.script ?= {}

class ScriptLoader
  constructor: ->
    @_scripts = {}
    addEventListener('message', @_sendSourceCode)

  _sendSourceCode: (e) =>
    script = window.script.Script.getScriptFromFrame @_scripts, e.source
    if script? and e.data.type == 'onload'
      script.postMessage { type: 'script', script: script }
      delete @_scripts[script.id]

  loadIntoFrame: (sourceCode) ->
    frame = @_createIframe()
    script = new window.script.Script sourceCode, frame
    @_scripts[script.id] = script
    script

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