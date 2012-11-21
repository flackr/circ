exports = window.irc ?= {}

##
# Handles messages from an IRC server.
##
class ServerResponseHandler extends MessageHandler

  constructor: (@irc) ->
    super
    @ctcpHandler = new window.irc.CTCPHandler

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
        for response in @ctcpHandler.getResponses msg
          @irc.doCommand 'NOTICE', from.nick, response, true
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

    # ERR_NICKNAMEINUSE
    433: (from, nick, taken) ->
      newNick = taken + '_'
      newNick = undefined if nick is newNick
      @irc.emitMessage 'nickinuse', chat.CURRENT_WINDOW, taken, newNick
      @irc.send 'NICK', newNick if newNick

    TOPIC: (from, channel, topic) ->
      if @irc.channels[channel]?
        @irc.channels[channel].topic = topic
        @irc.emitMessage 'topic', channel, from.nick, topic
      else
        console.warn "Got TOPIC for a channel we're not in (#{channel})"

    # rpl_notopic
    331: (from, to, channel, msg) ->
      @handle 'TOPIC', {}, channel

    # rpl_topic
    332: (from, to, channel, topic) ->
      @handle 'TOPIC', {}, channel, topic

    # rpl_topicwhotime
    333: (from, to, channel, who, time) ->
      # TODO show who set the topic and when

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

    #rpl_away
    301: (from, target, who, msg) ->
      # send a direct message from the user, saying the other user is away
      @irc.emitMessage 'privmsg', target, who, msg

    #rpl_unaway
    305: (from, to, msg) ->
      @irc.away = false
      @irc.emitMessage 'away', chat.CURRENT_WINDOW, msg

    #rpl_nowaway
    306: (from, to, msg) ->
      @irc.away = true
      @irc.emitMessage 'away', chat.CURRENT_WINDOW, msg

    #err_chanoprivsneeded
    482: (from, to, chan, msg) ->
      @irc.emitMessage 'error', chan, msg

exports.ServerResponseHandler = ServerResponseHandler