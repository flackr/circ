exports = window.irc ?= {}

class ServerResponseHandler extends AbstractMessageHandler

  handlers:
    # RPL_WELCOME
    1: (from, target, msg) ->
      @nick = target
      @emit 'connect'
      @state = 'connected'
      @emit 'message', undefined, 'welcome', msg
      for name,c of @channels
        @sendIfConnected 'JOIN', name

    # RPL_NAMREPLY
    353: (from, target, privacy, channel, names) ->
      l = (@partialNameLists[channel] ||= {})
      for n in names.split(/\x20/)
        n = n.replace /^[@+]/, '' # TODO: read the prefixes and modes that they imply out of the 005 message
        l[@util.normaliseNick n] = n
    # RPL_ENDOFNAMES
    366: (from, target, channel, _) ->
      if @channels[channel]
        @channels[channel].names = @partialNameLists[channel]
      else
        console.warn "Got name list for #{channel}, but we're not in it?"
      delete @partialNameLists[channel]

    NICK: (from, newNick, msg) ->
      if @util.nicksEqual from.nick, @nick
        @nick = newNick
      normNick = @util.normaliseNick from.nick
      newNormNick = @util.normaliseNick newNick
      for name,chan of @channels when normNick of chan.names
        delete chan.names[normNick]
        chan.names[newNormNick] = newNick
        @emit 'message', chan, 'nick', from.nick, newNick

    JOIN: (from, chan) ->
      if @util.nicksEqual from.nick, @nick
        if c = @channels[chan]
          c.names = []
        else
          @channels[chan] = {names:[]}
        @emit 'joined', chan
      if c = @channels[chan]
        c.names[@util.normaliseNick from.nick] = from.nick
        @emit 'message', chan, 'join', from.nick
      else
        console.warn "Got JOIN for channel we're not in (#{channel})"

    PART: (from, chan) ->
      # TODO: when do we receive PART? can the server just PART us?
      if c = @channels[chan]
        delete c.names[@util.normaliseNick from.nick]
        @emit 'message', chan, 'part', from.nick
      else
        console.warn "Got PART for channel we're not in (#{channel})"

      if @util.nicksEqual from.nick, @nick
        @channels[chan]?.names = []
        @emit 'parted', chan

    QUIT: (from, reason) ->
      normNick = @util.normaliseNick from.nick
      for name, chan of @channels when normNick of chan.names
        delete chan.names[normNick]
        @emit 'message', chan, 'quit', from.nick

    PRIVMSG: (from, target, msg) ->
      # TODO: normalise channel target names
      # TODO: should we pass more info about from?
      @emit 'message', target, 'privmsg', from.nick, msg

    PING: (from, payload) ->
      @send 'PONG', payload

    PONG: (from, payload) -> # ignore for now. later, lag calc.

    # ERR_NICKNAMEINUSE
    433: (from, nick, msg) ->
      @preferredNick += '_'
      @emit 'message', undefined, 'nickinuse', nick, @opts.nick, msg
      @send 'NICK', @opts.nick

exports.ServerResponseHandler = ServerResponseHandler