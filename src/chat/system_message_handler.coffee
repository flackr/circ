exports = window.chat ?= {}

class SystemMessageHandler extends MessageHandler
  constructor: (@chat) ->
    super

  handle: (type, @_conn, params...) ->
    super type, params...

  _handlers:
    welcome: (msg) ->
      @_message msg, 'welcome'

    unknown: (cmd) ->
      @_message cmd.command + ' ' + cmd.params.join(' ')

    error: (err) ->
      @_message err

    nickinuse: (newnick, inUse) ->
      @_message "Nickname #{inUse} already in use. Trying to get nickname #{newnick}."

    nick_changed: (newnick) ->
      @_message "You are now known as #{newnick}"
      @chat.updateStatus()

    connect: ->
      @_message "Connected. Now logging in..."

    disconnect: ->
      @_message "Disconnected"

    privmsg: (to, msg) ->
      source = ">#{to}<"
      @_conn.serverWindow.message source, msg, 'update privmsg direct'

  _message: (msg) ->
    @_conn.serverWindow.message '*', msg

exports.SystemMessageHandler = SystemMessageHandler
