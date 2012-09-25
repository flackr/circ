exports = window.irc ?= {}

class ServerResponseHandler extends MessageHandler

  constructor: (@irc) ->
    super

  _handlers:
    # RPL_WELCOME
    1: (from, target, msg) ->
      @irc.nick = target
      @irc.emit 'connect'
      @irc.state = 'connected'
      @irc.emitMessage 'welcome', undefined, msg
      for name,c of @irc.channels
        @irc.sendIfConnected 'JOIN', name

    # RPL_NAMREPLY
    353: (from, target, privacy, channel, names) ->
      l = (@irc.partialNameLists[channel] ||= {})
      newNames = []
      for n in names.split(/\x20/)
        # TODO: read the prefixes and modes that they imply out of the 005 message
        n = n.replace /^[@+]/, ''
        l[irc.util.normaliseNick n] = n
        newNames.push n
      @irc.emit 'names', channel, newNames
    # RPL_ENDOFNAMES
    366: (from, target, channel, _) ->
      if @irc.channels[channel]
        @irc.channels[channel].names = @irc.partialNameLists[channel]
      delete @irc.partialNameLists[channel]

    NICK: (from, newNick, msg) ->
      if irc.util.nicksEqual from.nick, @irc.nick
        @irc.nick = newNick
        @irc.emitMessage 'nick_changed', undefined, newNick
      normNick = @irc.util.normaliseNick from.nick
      newNormNick = @irc.util.normaliseNick newNick
      for chanName, chan of @irc.channels when normNick of chan.names
        delete chan.names[normNick]
        chan.names[newNormNick] = newNick
        @irc.emitMessage 'nick', chanName, from.nick, newNick

    JOIN: (from, chanName) ->
      isOwnNick = irc.util.nicksEqual from.nick, @irc.nick
      chan = @irc.channels[chanName]
      if isOwnNick
        if chan?
          chan.names = []
        else
          chan = @irc.channels[chanName] = {names:[]}
        @irc.emit 'joined', chanName
      if chan?
        chan.names[irc.util.normaliseNick from.nick] = from.nick
        @irc.emitMessage 'join', chanName, from.nick
      else
        console.warn "Got JOIN for channel we're not in (#{chan})"

    PART: (from, chan) ->
      if c = @irc.channels[chan]
        @irc.emitMessage 'part', chan, from.nick
        if irc.util.nicksEqual from.nick, @irc.nick
          c.names = []
          @irc.emit 'parted', chan
        else
          delete c.names[irc.util.normaliseNick from.nick]
      else
        console.warn "Got PART for channel we're not in (#{chan})"

    QUIT: (from, reason) ->
      normNick = irc.util.normaliseNick from.nick
      for chanName, chan of @irc.channels when normNick of chan.names
        delete chan.names[normNick]
        @irc.emitMessage 'quit', chanName, from.nick, reason

    PRIVMSG: (from, target, msg) ->
      # TODO: normalise channel target names
      # TODO: should we pass more info about from?
      @irc.emitMessage 'privmsg', target, from.nick, msg

    PING: (from, payload) ->
      @irc.send 'PONG', payload

    PONG: (from, payload) -> # ignore for now. later, lag calc.

    # ERR_NICKNAMEINUSE
    433: (from, nick, msg) ->
      @irc.preferredNick = msg
      @irc.preferredNick += '_'
      @irc.emitMessage 'nickinuse', undefined, nick, @irc.preferredNick, msg
      @irc.send 'NICK', @irc.preferredNick

exports.ServerResponseHandler = ServerResponseHandler