describe 'IRC sync storage', ->
  ss = chat = undefined
  sync = chrome.storage.sync

  beforeEach ->
    chat = jasmine.createSpyObj 'chat', ['connect', 'join', 'updateStatus']
    chat.connections = { freenode: 'f', dalnet: 'd' }
    ss = new window.chat.SyncStorage
    sync.clear()

  it 'does nothing when there is no state to restore', ->
    ss.restoreState chat
    expect(chat.connect).not.toHaveBeenCalled()
    expect(chat.join).not.toHaveBeenCalled()
    expect(chat.updateStatus).not.toHaveBeenCalled()
    expect(chat.previousNick).toBe undefined

  it 'restores the stored nick', ->
    sync.set { nick: 'ournick' }
    ss.restoreState chat
    expect(chat.previousNick).toBe 'ournick'

  it 'restores the stored servers', ->
    sync.set { servers: [
        {name: 'freenode', port: 6667},
        {name: 'dalnet', port: 6697}]}
    ss.restoreState chat
    expect(chat.connect).toHaveBeenCalledWith('freenode', 6667)
    expect(chat.connect).toHaveBeenCalledWith('dalnet', 6697)

  it 'restores the stored channels', ->
    sync.set { channels: [
        {name: '#bash', server: 'freenode'},
        {name: '#awesome', server: 'freenode'},
        {name: '#hiphop', server: 'dalnet'}]}

    ss.restoreState chat
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
