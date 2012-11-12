exports = window

class Context

  constructor: (@server, @channel) ->

  toString: ->
    if @channel
      @server + ' ' + @channel
    else
      @server

  @fromString: (str) ->
    new Context str.split(' ')...

  @wrap: (obj) ->
    obj.toString = @::toString
    return obj

exports.Context = Context
