exports = window.chat ?= {}

##
# An ordered list of windows with channels sorted by server then alphebetically
# by name.
##
class WindowList
  constructor: ->
    @_servers = []
    @length = 0

  get: (serverName, chan) ->
    if typeof arguments[0] == 'number'
      return @_getByNumber arguments[0]
    for server in @_servers
      continue unless serverName == server.name
      return server.serverWindow unless chan?
      for win in server.windows
        return win if win.target == chan
    undefined

  _getByNumber: (num) ->
    for server in @_servers
      if num == 0 then return server.serverWindow
      else num -= 1
      if num < server.windows.length
        return server.windows[num]
      else
        num -= server.windows.length
    undefined

  ##
  # The same as get(), but the index excludes server windows.
  ##
  getChannelWindow: (index) ->
    for server in @_servers
      if index < server.windows.length
        return server.windows[index]
      else
        index -= server.windows.length
    undefined

  ##
  # The same as get(), but the index excludes channel windows.
  ##
  getServerWindow: (index) ->
    return @_servers[index]?.serverWindow

  add: (win) ->
    if win.target?
      @_addChannelWindow win
    else
      @_addServerWindow win
    @length++

  _addChannelWindow: (win) ->
    assert win.conn?.name?
    for server in @_servers
      if win.conn.name == server.name
        @_addWindowToServer server, win
        return
    throw 'added channel window with no corresponding connection window: ' + win

  _addWindowToServer: (server, win) ->
    server.windows.push win
    server.windows.sort (win1, win2) ->
      return win1.target > win2.target

  _addServerWindow: (win) ->
    assert win.conn?.name?
    @_servers.push { name: win.conn.name, serverWindow: win, windows: [] }

  remove: (win) ->
    for server, i in @_servers
      if server.name == win.conn?.name
        if win.isServerWindow()
          @_servers.splice i, 1
          @length -= server.windows.length + 1
          return server.windows.concat [server.serverWindow]
        for candidate, i in server.windows
          if candidate.target == win.target
            server.windows.splice i, 1
            @length--
            return [candidate]
    return []

  ##
  # Given a window, returns its corresponding server window.
  # @param {Window} win
  # @return {Window|undefined} The server window.
  ##
  getServerForWindow: (win) ->
    return win if win.isServerWindow()
    for server in @_servers
      return server.serverWindow if server.name is win.conn?.name
    return undefined

  indexOf: (win) ->
    return -1 unless win.conn?.name?
    count = 0
    for server in @_servers
      if win.conn.name == server.name
        return count unless win.target?
        count++
        for candidate, i in server.windows
          return count + i if candidate.equals win
        return -1
      else
        count += server.windows.length + 1
    -1

  ##
  # Return the index of a channel relative to other channels of the same server.
  ##
  localIndexOf: (win) ->
    return -1 unless win.conn?.name?
    for server in @_servers
      continue unless win.conn.name is server.name
      for candidate, i in server.windows
        return i if candidate.equals win
    return -1

  ##
  # Returns the index of a server relative to other servers.
  ##
  serverIndexOf: (win) ->
    return -1 unless win.conn?.name?
    for server, i in @_servers
      return i if win.conn.name is server.name
    return -1

exports.WindowList = WindowList
