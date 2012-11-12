describe 'A chat log', ->
  chatLog = undefined

  context1 = new Context "freenode", "#bash"
  context2 = new Context "freenode", "#awesome"

  beforeEach ->
    chatLog = new chat.ChatLog

  it "can log chat messages", ->
    chatLog.whitelist 'privmsg'
    chatLog.add context1, 'privmsg update self', 'some content'
    chatLog.add context1, 'privmsg update', 'some more content'
    chatLog.add context1, 'privmsg', 'even more content'

    log = chatLog.get context1
    expect(log).toBe 'some content some more content even more content'

    log2 = chatLog.get context2
    expect(log2).not.toBeDefined()

  it "only keeps messages with a whitelisted type", ->
    chatLog.whitelist 'privmsg'

    chatLog.add context1, 'notice', 'some content'
    expect(chatLog.get context1).not.toBeDefined()

    chatLog.add context1, 'privmsg', 'some content'
    expect(chatLog.get context1).toBeDefined()

  it "can list all contexts where logged messages came from", ->
    chatLog.whitelist 'privmsg'

    for i in [0..99]
      context = new Context "freenode#{i%10}", "#channel#{i}"
      chatLog.add context, 'privmsg', "I like the number #{i}"
    expect(chatLog.getContextList().length).toBe 100
    expect(chatLog.getContextList()[8]).toEqual new Context 'freenode8', '#channel8'

  it "can load data from another chat log", ->
    chatLog.whitelist 'privmsg'
    chatLog.add context1, 'privmsg', 'some data'
    chatLog.add context2, 'privmsg', 'some more data'
    data = chatLog.getData()
    serializedData = JSON.stringify data

    data = JSON.parse serializedData
    chatLog = new chat.ChatLog
    chatLog.loadData data
    expect(chatLog.get context1).toBe 'some data'
    expect(chatLog.get context2).toBe 'some more data'

  it "has a limit of messages entries per window", ->
    chatLog.whitelist 'privmsg'
    for i in [0..999]
      chatLog.add context1, 'privmsg', i

    expect(chatLog.get(context1).split(' ').length).toBe 1000
    chatLog.add context1, 'privmsg', 'newest_data'
    expect(chatLog.get(context1).split(' ').length <= 1000).toBe true
    entries = chatLog.get(context1).split(' ')
    expect(entries[entries.length-1]).toBe 'newest_data'