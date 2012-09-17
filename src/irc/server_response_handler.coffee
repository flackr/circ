exports = window.irc ?= {}

class ServerResponseHandler extends MessageHandler

  constructor: (source) ->
    super source
    @registerHandlers @_serverResponses

  _serverResponses:
    # RPL_WELCOME
    1: (from, target, msg) ->
      @nick = target
      @emit 'connect'
      @state = 'connected'
      @emitMessage 'welcome', undefined, msg
      for name,c of @channels
        @sendIfConnected 'JOIN', name

    # RPL_NAMREPLY
    353: (from, target, privacy, channel, names) ->
      l = (@partialNameLists[channel] ||= {})
      newNames = []
      for n in names.split(/\x20/)
        n = n.replace /^[@+]/, '' # TODO: read the prefixes and modes that they imply out of the 005 message
        l[@util.normaliseNick n] = n
        newNames.push n
      @emit 'names', channel, newNames
    # RPL_ENDOFNAMES
    366: (from, target, channel, _) ->
      if @channels[channel]
        @channels[channel].names = @partialNameLists[channel]
      delete @partialNameLists[channel]

    NICK: (from, newNick, msg) ->
      if @util.nicksEqual from.nick, @nick
        @nick = newNick
      normNick = @util.normaliseNick from.nick
      newNormNick = @util.normaliseNick newNick
      for chanName, chan of @channels when normNick of chan.names
        delete chan.names[normNick]
        chan.names[newNormNick] = newNick
        @emitMessage 'nick', chanName, from.nick, newNick

    JOIN: (from, chan) ->
      if @util.nicksEqual from.nick, @nick
        if c = @channels[chan]
          c.names = []
        else
          @channels[chan] = {names:[]}
        @emit 'joined', chan
      else if c = @channels[chan]
        c.names[@util.normaliseNick from.nick] = from.nick
        @emitMessage 'join', chan, from.nick
      else
        console.warn "Got JOIN for channel we're not in (#{chan})"

    PART: (from, chan) ->
      weLeft = @util.nicksEqual from.nick, @nick
      if c = @channels[chan]
        unless weLeft
          delete c.names[@util.normaliseNick from.nick]
          @emitMessage 'part', chan, from.nick
      else
        console.warn "Got PART for channel we're not in (#{channel})"

      if weLeft
        @channels[chan]?.names = []
        @emit 'parted', chan

    QUIT: (from, reason) ->
      normNick = @util.normaliseNick from.nick
      for chanName, chan of @channels when normNick of chan.names
        delete chan.names[normNick]
        @emitMessage 'quit', chanName, from.nick, reason

    PRIVMSG: (from, target, msg) ->
      # TODO: normalise channel target names
      # TODO: should we pass more info about from?
      @emitMessage 'privmsg', target, from.nick, msg

    PING: (from, payload) ->
      @send 'PONG', payload

    PONG: (from, payload) -> # ignore for now. later, lag calc.

    # ERR_NICKNAMEINUSE
    433: (from, nick, msg) ->
      @preferredNick += '_'
      @emitMessage 'nickinuse', undefined, nick, @preferredNick, msg
      @send 'NICK', @preferredNick

exports.ServerResponseHandler = ServerResponseHandler