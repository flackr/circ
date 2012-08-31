exports = window

exports.assert = (cond) ->
  throw new Error("assertion failed") unless cond
