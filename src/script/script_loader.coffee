exports = window.script ?= {}

class ScriptLoader

  @AUTOLOAD_PATH = 'scripts'

  constructor: ->
    @_scripts = {}
    addEventListener 'message', @_sendSourceCode

  _sendSourceCode: (e) =>
    script = window.script.Script.getScriptFromFrame @_scripts, e.source
    if script and e.data.type is 'onload'
      script.postMessage { type: 'source_code', sourceCode: script.sourceCode }
      delete @_scripts[script.id]

  loadPrepackagedScripts: (callback) ->
    for sourceCode in window.script.prepackagedScripts
      callback @_createScript sourceCode

  createScriptFromFileSystem: (callback) ->
    chrome.fileSystem.chooseFile { type: 'openFile' }, (f) =>
      @_onChosenFileToOpen f, callback

  _onChosenFileToOpen: (fileEntry, callback) ->
    fileEntry.file (file) =>
      fileReader = new FileReader()

      fileReader.onload = (e) =>
        sourceCode = e.target.result
        try
          callback @_createScript sourceCode
        catch error
          console.error 'failed to eval:', error.toString()

      fileReader.onerror = (e) ->
        console.error 'Read failed:', e.toString()

      fileReader.readAsText file

  _createScript: (sourceCode) ->
    frame = @_createIframe()
    script = new window.script.Script sourceCode, frame
    @_scripts[script.id] = script
    script

  _createIframe: ->
    iframe = document.createElement('iframe')
    iframe.src = 'script_frame.html'
    iframe.style.display = 'none'
    document.body.appendChild(iframe)
    iframe.contentWindow

exports.loader = new ScriptLoader()