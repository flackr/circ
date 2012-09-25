exports = window.chat ?= {}

class WindowList
  constructor: ->
    @_servers = []

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

  getChannelWindow: (serverName, chan) ->
    if typeof arguments[0] == 'number'
      return @_getChannelWindowByNumber arguments[0]
    for server in @_servers
      continue unless serverName == server.name
      for win in server.windows
        return win if win.target == chan
    undefined

  _getChannelWindowByNumber: (num) ->
    for server in @_servers
      if num < server.windows.length
        return server.windows[num]
      else
        num -= server.windows.length
    undefined

  add: (win) ->
    if win.target?
      @_addChannelWindow win
    else
      @_addServerWindow win

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
        if not win.target?
          @_servers.splice i, 1
          return [server.serverWindow].concat server.windows
        for candidate, i in server.windows
          if candidate.target == win.target
            server.windows.splice i, 1
            return [candidate]
    return []

  indexOf: (win) ->
    assert win.conn?.name?
    count = 0
    for server in @_servers
      if win.conn.name == server.name
        return count unless win.target?
        count++
        for candidate, i in server.windows
          return count + i if candidate.target == win.target
        return -1
      else
        count += server.windows.length + 1
    -1

exports.WindowList = WindowList
