exports = window.irc ?= {}

class CTCPHandler
  constructor: ->
    @_delimeter = '\u0001'
    @_error ="#{@_delimeter}ERRMSG#{@_delimeter}"

  isCTCPRequest: (msg) ->
    return false unless /\u0001[\w\s]*\u0001/.test msg
    return @getResponses(msg).length > 0

  getResponses: (msg) ->
    @_parseMessage msg
    responses = @_getResponseText()
    result = []
    for response in responses
      console.log response
      result.push "#{@_delimeter}#{@type}#{response}#{@_delimeter}"
    result

  _getResponseText: ->
    # TODO support the o ther types found here:
    # http://www.irchelp.org/irchelp/rfc/ctcpspec.html
    switch @type
      when 'VERSION'
        name = 'CIRC'
        environment = 'Chrome'
        [' ' + [name, irc.VERSION, environment].join ':']
      when 'SOURCE'
        [''] # TODO add details when client is available over FTP
      when 'PING'
        [' ' + @args[0]]
      else []

  _parseMessage: (msg) ->
    msg = msg[1..msg.length-2]
    split = msg.split ' '
    @type = split[0]
    @args = split[1..]

exports.CTCPHandler = CTCPHandler