exports = window.irc ?= {}

##
# Handles messages from an IRC server.
##
class ServerResponseHandler extends MessageHandler

  constructor: (@irc) ->
    super
    @ctcpHandler = new window.irc.CTCPHandler

  canHandle: (type) ->
    if @_isErrorMessage(type) then true
    else super type

  ##
  # Handle a message of the given type. Error messages are handled with the
  # default error handler unless a handler is explicitly specified.
  # @param {string} type The type of message (e.g. PRIVMSG).
  # @param {object...} params A variable number of arguments.
  ##
  handle: (type, params...) ->
    if @_isErrorMessage(type) and not (type of @_handlers)
      type = 'error'
    super type, params...

  _isErrorMessage: (type) ->
    400 <= parseInt(type) < 600

  _handlers:
    # rpl_welcome
    1: (from, nick, msg) ->
      if @irc.state is 'disconnecting'
        @irc.quit()
        return
      @irc.nick = nick
      @irc.state = 'connected'
      @irc.emit 'connect'
      @irc.emitMessage 'welcome', chat.SERVER_WINDOW, msg
      for name,c of @irc.channels
        @irc.send 'JOIN', name

    # rpl_namreply
    353: (from, target, privacy, channel, names) ->
      nameList = @irc.partialNameLists[channel] ?= {}
      newNames = []
      for n in names.split(/\x20/)
        # TODO: read the prefixes and modes that they imply out of the 005 message
        n = n.replace /^[~&@%+]/, ''
        if n
          nameList[irc.util.normaliseNick n] = n
          newNames.push n
      @irc.emit 'names', channel, newNames

    # rpl_endofnames
    366: (from, target, channel, _) ->
      if @irc.channels[channel]
        @irc.channels[channel].names = @irc.partialNameLists[channel]
      delete @irc.partialNameLists[channel]

    NICK: (from, newNick, msg) ->
      if @irc.isOwnNick from.nick
        @irc.nick = newNick
        @irc.emit 'nick', newNick
        @irc.emitMessage 'nick', chat.SERVER_WINDOW, from.nick, newNick
      normNick = @irc.util.normaliseNick from.nick
      newNormNick = @irc.util.normaliseNick newNick
      for chanName, chan of @irc.channels when normNick of chan.names
        delete chan.names[normNick]
        chan.names[newNormNick] = newNick
        @irc.emitMessage 'nick', chanName, from.nick, newNick

    JOIN: (from, chanName) ->
      chan = @irc.channels[chanName]
      if @irc.isOwnNick from.nick
        if chan?
          chan.names = []
        else
          chan = @irc.channels[chanName] = {names:[]}
        @irc.emit 'joined', chanName
      if chan
        chan.names[irc.util.normaliseNick from.nick] = from.nick
        @irc.emitMessage 'join', chanName, from.nick
      else
        console.warn "Got JOIN for channel we're not in (#{chan})"

    PART: (from, chan) ->
      if c = @irc.channels[chan]
        @irc.emitMessage 'part', chan, from.nick
        if @irc.isOwnNick from.nick
          delete @irc.channels[chan]
          @irc.emit 'parted', chan
        else
          delete c.names[irc.util.normaliseNick from.nick]
      else
        console.warn "Got TOPIC for a channel we're not in: #{chan}"

    QUIT: (from, reason) ->
      normNick = irc.util.normaliseNick from.nick
      for chanName, chan of @irc.channels when normNick of chan.names
        delete chan.names[normNick]
        @irc.emitMessage 'quit', chanName, from.nick, reason

    PRIVMSG: (from, target, msg) ->
      if @ctcpHandler.isCTCPRequest msg
        @_handleCTCPRequest from, target, msg
      else
        @irc.emitMessage 'privmsg', target, from.nick, msg

    NOTICE: (from, target, msg) ->
      if not from.user
        return @irc.emitMessage 'notice', chat.SERVER_WINDOW, msg
      event = new Event 'message', 'privmsg', from.nick, msg
      event.setContext @irc.server, chat.CURRENT_WINDOW
      event.addStyle 'notice'
      @irc.emitCustomMessage event

    PING: (from, payload) ->
      @irc.send 'PONG', payload

    PONG: (from, payload) -> # ignore for now. later, lag calc.

    TOPIC: (from, channel, topic) ->
      if @irc.channels[channel]?
        @irc.channels[channel].topic = topic
        @irc.emitMessage 'topic', channel, from.nick, topic
      else
        console.warn "Got TOPIC for a channel we're not in (#{channel})"

    KICK: (from, channel, to, reason) ->
      if not @irc.channels[channel]
        console.warn "Got KICK message from #{from} to #{to} in channel we are not in (#{channel})"
        return

      delete @irc.channels[channel].names[to]
      @irc.emitMessage 'kick', channel, from.nick, to, reason
      if @irc.isOwnNick to
        @irc.emit 'parted', channel

    MODE: (from, chan, mode, to) ->
      @irc.emitMessage 'mode', chan, from.nick, to, mode

    # rpl_umodeis
    221: (from, to, mode) ->
      @irc.emitMessage 'user_mode', chat.CURRENT_WINDOW, to, mode

    # rpl_away
    301: (from, target, who, msg) ->
      # send a direct message from the user, saying the other user is away
      @irc.emitMessage 'privmsg', target, who, msg

    # rpl_unaway
    305: (from, to, msg) ->
      @irc.away = false
      @irc.emitMessage 'away', chat.CURRENT_WINDOW, msg

    # rpl_nowaway
    306: (from, to, msg) ->
      @irc.away = true
      @irc.emitMessage 'away', chat.CURRENT_WINDOW, msg

    # rpl_channelmodeis
    324: (from, to, channel, mode, modeParams) ->
      message = "Channel modes: #{mode} #{modeParams ? ''}"
      @irc.emitMessage 'notice', channel, message

    # rpl_channelcreated
    329: (from, to, channel, time) ->
      readableTime = new Date(parseInt time)
      message = "Channel created on #{readableTime}"
      @irc.emitMessage 'notice', channel, message

    # rpl_notopic
    331: (from, to, channel, msg) ->
      @handle 'TOPIC', {}, channel

    # rpl_topic
    332: (from, to, channel, topic) ->
      @handle 'TOPIC', {}, channel, topic

    # rpl_topicwhotime
    333: (from, to, channel, who, time) ->
      @irc.emitMessage 'topic_info', channel, who, time

    # err_nicknameinuse
    433: (from, nick, taken) ->
      newNick = taken + '_'
      newNick = undefined if nick is newNick
      @irc.emitMessage 'nickinuse', chat.CURRENT_WINDOW, taken, newNick
      @irc.send 'NICK', newNick if newNick

    ##
    # The default error handler for error messages. This handler is used for all
    # 4XX error messages unless a handler is explicitly specified.
    #
    # Messages are displayed in the following format:
    #   "<arg1> <arg2> ... <argn>: <message>
    ##
    error: (from, to, args..., msg) ->
      if args.length > 0
        message = "#{args.join ' '} :#{msg}"
      else
        message = msg
      @irc.emitMessage 'error', chat.CURRENT_WINDOW, message

    KILL: (from, victim, killer, msg) ->
      @irc.emitMessage 'kill', chat.CURRENT_WINDOW, killer.nick, victim, msg

  _handleCTCPRequest: (from, target, msg) ->
    name = @ctcpHandler.getReadableName msg
    message = "Received a CTCP #{name} from #{from.nick}"
    @irc.emitMessage 'notice', chat.CURRENT_WINDOW, message
    for response in @ctcpHandler.getResponses msg
      @irc.doCommand 'NOTICE', from.nick, response, true

exports.ServerResponseHandler = ServerResponseHandler
