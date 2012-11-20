exports = window.irc ?= {}

##
# Handles CTCP requests such as VERSION, PING, etc.
##
class CTCPHandler
  constructor: ->
    @_delimeter = '\u0001'

    # TODO: Respond with this message when an unknown query is seen.
    @_error ="#{@_delimeter}ERRMSG#{@_delimeter}"

  isCTCPRequest: (msg) ->
    return false unless /\u0001[\w\s]*\u0001/.test msg
    return @getResponses(msg).length > 0

  getResponses: (msg) ->
    [type, args] = @_parseMessage msg
    responses = @_getResponseText type, args
    (@_createCTCPResponse(type, response) for response in responses)

  ##
  # Parses the type and arguments from a CTCP request.
  # @param {string} msg CTCP message in the format: '\0001TYPE ARG1 ARG2\0001'.
  #     Note: \0001 is a single character.
  # @return {string, Array.<string>} Returns the type and the args.
  ##
  _parseMessage: (msg) ->
    msg = msg[1..msg.length-2] # strip the \0001's
    [type, args...] = msg.split ' '
    [type, args]

  ##
  # @return {Array.<string>} Returns the unformatted responses to a CTCP
  #     request.
  ##
  _getResponseText: (type, args) ->
    # TODO support the o ther types found here:
    # http://www.irchelp.org/irchelp/rfc/ctcpspec.html
    switch type
      when 'VERSION'
        name = 'CIRC'
        environment = 'Chrome'
        [' ' + [name, irc.VERSION, environment].join ':']
      when 'SOURCE'
        [''] # TODO add details when client is available over FTP
      when 'PING'
        [' ' + args[0]]
      else []

  ##
  # @return {string} Returns a correctly formatted response to a CTCP request.
  ##
  _createCTCPResponse: (type, response) ->
    "#{@_delimeter}#{type}#{response}#{@_delimeter}"

exports.CTCPHandler = CTCPHandler