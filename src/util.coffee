window.assert = (cond) ->
  throw new Error("assertion failed") unless cond

window.concatArrayBuffers = (a, b) ->
  result = new ArrayBuffer a.byteLength + b.byteLength
  resultView = new Uint8Array result
  resultView.set new Uint8Array a
  resultView.set new Uint8Array(b), a.byteLength
  result

window.string2ArrayBuffer = (string, callback) ->
  blob = new Blob [string]
  f = new FileReader()
  f.onload = (e) ->
    callback(e.target.result)
  f.readAsArrayBuffer(blob)

window.arrayBuffer2String = (buf, callback) ->
  blob = new Blob [new DataView buf]
  f = new FileReader()
  f.onload = (e) ->
    callback(e.target.result)
  f.readAsText(blob)
