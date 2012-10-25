describe 'IRC sync storage', ->
  ss = chat = undefined
  sync = chrome.storage.sync

  beforeEach ->
    chat = jasmine.createSpyObj 'chat', ['connect', 'join', 'updateStatus',
        'setNick', 'setPassword']
    chat.remoteConnection = { isSupported: -> true }
    chat.remoteConnection.connectToServer = jasmine.createSpy 'connectToServer'
    chat.connections = { freenode: 'f', dalnet: 'd' }

    ss = new window.chat.SyncStorage
    sync.clear()

  it 'does nothing when there is no state to restore', ->
    ss.restoreSavedState chat
    expect(chat.connect).not.toHaveBeenCalled()
    expect(chat.join).not.toHaveBeenCalled()
    expect(chat.updateStatus).not.toHaveBeenCalled()
    expect(chat.setNick).not.toHaveBeenCalled()

  it 'does nothing when there syncing has been paused', ->
    ss.pause()
    ss.nickChanged 'bob'
    ss.serverJoined 'freenode'
    ss.channelJoined 'freenode', '#bash'
    ss.restoreSavedState chat
    expect(chat.connect).not.toHaveBeenCalled()
    expect(chat.join).not.toHaveBeenCalled()
    expect(chat.updateStatus).not.toHaveBeenCalled()
    expect(chat.setNick).not.toHaveBeenCalled()

  it 'sets a new password if one is not found', ->
    ss.restoreSavedState chat
    expect(ss._password).toEqual jasmine.any(String)

  it 'restores the password if it was cleared', ->
    ss.restoreSavedState chat
    password = ss._password
    chrome.storage.update { password: { newValue: undefined } }, 'sync'
    expect(sync._storageMap.password).toBe password

  it 'restores the stored nick', ->
    sync.set { nick: 'ournick' }
    ss.restoreSavedState chat
    expect(chat.setNick).toHaveBeenCalledWith 'ournick'

  it 'restores the stored password', ->
    sync.set { password: 'somepw' }
    ss.restoreSavedState chat
    expect(chat.setPassword).toHaveBeenCalledWith 'somepw'

  it 'restores the stored servers', ->
    sync.set { servers: [
        {name: 'freenode', port: 6667},
        {name: 'dalnet', port: 6697}]}
    ss.restoreSavedState chat
    expect(chat.connect).toHaveBeenCalledWith('freenode', 6667)
    expect(chat.connect).toHaveBeenCalledWith('dalnet', 6697)

  it 'restores the stored channels', ->
    sync.set { channels: [
        {name: '#bash', server: 'freenode'},
        {name: '#awesome', server: 'freenode'},
        {name: '#hiphop', server: 'dalnet'}]}

    ss.restoreSavedState chat
    expect(chat.join).toHaveBeenCalledWith('f', '#bash')
    expect(chat.join).toHaveBeenCalledWith('f', '#awesome')
    expect(chat.join).toHaveBeenCalledWith('d', '#hiphop')

  it 'stores the new nick on nickChanged()', ->
    ss.nickChanged 'newnick'
    expect(sync._storageMap.nick).toBe 'newnick'

  it 'stores the joined channel on channelJoined()', ->
    ss.channelJoined 'freenode', '#bash'
    expect(sync._storageMap.channels).toEqual [{name: '#bash', server: 'freenode'}]

  it 'removes the stored channel on channelParted()', ->
    ss.channelJoined 'freenode', '#bash'
    ss.parted 'freenode', '#bash'
    expect(sync._storageMap.channels).toEqual []

  it 'stores the joined server on serverJoined()', ->
    ss.serverJoined 'freenode', 6667
    expect(sync._storageMap.servers).toEqual [{name: 'freenode', port: 6667}]

  it 'removes the stored server on serverParted()', ->
    ss.serverJoined 'freenode', 6697
    ss.parted 'freenode', 6697
    expect(sync._storageMap.channels).toEqual []

  it 'loads the stored server device', ->
    connectInfo = { addr: '1.1.1.1', port: 1 }
    sync.set { remote_server: connectInfo }
    ss.restoreSavedState chat
    expect(ss.remoteServer).toEqual connectInfo

  it 'can store a new server device', ->
    connectInfo = { addr: '1.1.1.1', port: 1 }
    ss.becomeRemoteServer connectInfo
    expect(sync._storageMap.remote_server).toEqual connectInfo

  it 'connects to the server automatically when a new server is set', ->
    connectInfo = { addr: '1.1.1.2', port: 1 }
    sync.set { remote_server: { addr: '1.1.1.1', port: 1 } }
    ss.restoreSavedState chat
    chrome.storage.update { remote_server: { newValue: connectInfo } }, 'sync'
    expect(chat.remoteConnection.connectToServer).toHaveBeenCalledWith connectInfo

  it "doesn't connect to itself when it sets the server", ->
    connectInfo = { addr: '1.1.1.1', port: 1 }
    sync.set { remote_server: { addr: '1.1.1.1', port: 1 } }
    ss.restoreSavedState chat
    chrome.storage.update { remote_server: { newValue: connectInfo } }, 'sync'
    expect(chat.remoteConnection.connectToServer).not.toHaveBeenCalled()