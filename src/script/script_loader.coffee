exports = window.script ?= {}

class ScriptLoader

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

  loadScriptsFromStorage: (scripts, callback) ->
    for script in scripts
      callback @_createScript script.sourceCode

  createScriptFromFileSystem: (callback) ->
    loadFromFileSystem (sourceCode) =>
      try
        callback @_createScript sourceCode
      catch error
        console.error 'failed to eval:', error.toString()

  ##
  # @param {string} sourceCode The raw JavaScript source code of the script.
  # @return {Script} Returns a handle to the script.
  ##
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

  ##
  # Removes the iFrame in which the script is running from the DOM.
  # @param {Script} script
  ##
  unloadScript: (script) ->
    document.body.removeChild(script.frame)
    delete script.frame

exports.loader = new ScriptLoader()