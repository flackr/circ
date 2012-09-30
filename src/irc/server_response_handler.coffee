exports = window.irc ?= {}

class ServerResponseHandler extends MessageHandler

  constructor: (@irc) ->
    super

  _handlers:
    # RPL_WELCOME
    1: (from, target, msg) ->
      if @irc.state is 'disconnecting'
        @irc.quit()
        return
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
        console.warn "Got TOPIC for a channel we're not in: #{chan}"

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
    433: (from, nick, inUse) ->
      @irc.preferredNick = inUse
      @irc.preferredNick += '_'
      # don't try to set your nick name to itself
      @irc.preferredNick += '_' if @irc.preferredNick is nick
      @irc.emitMessage 'nickinuse', undefined, @irc.preferredNick, inUse
      @irc.send 'NICK', @irc.preferredNick

    TOPIC: (from, channel, topic) ->
      if @irc.channels[channel]?
        @irc.channels[channel].topic = topic
        @irc.emitMessage 'topic', channel, from.nick, topic
      else
        console.warn "Got TOPIC for a channel we're not in: #{channel}"

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
      if irc.util.nicksEqual @irc.nick, to
        @irc.emit 'parted', channel

    MODE: (from, chan, mode, to) ->
      @irc.emitMessage 'mode', chan, from.nick, to, mode

    #rpl_away
    301: (from, target, who, msg) ->
      @irc.emitMessage 'privmsg', target, who, msg

    #rpl_unaway
    305: (from, to, msg) ->
      @irc.status.away = false
      @irc.emitMessage 'away', undefined, msg

    #rpl_nowaway
    306: (from, to, msg) ->
      @irc.status.away = true
      @irc.emitMessage 'away', undefined, msg

    #err_chanoprivsneeded
    482: (from, to, chan, msg) ->
      @irc.emitMessage 'notice', chan, msg

exports.ServerResponseHandler = ServerResponseHandler