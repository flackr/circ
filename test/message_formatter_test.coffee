describe "A message formatter", ->
  formatter = undefined

  beforeEach ->
    formatter = new chat.MessageFormatter
    formatter.setNick 'ournick'
    formatter.setCustomStyle 'purple'

  it "returns an empty string when no message has been set", ->
    expect(formatter.format()).toBe ''

  it "adds a period to the end of the message", ->
    formatter.setMessage 'No topic set'
    expect(formatter.format()).toBe 'No topic set.'

  it "capitalises the first letter of the message", ->
    formatter.setMessage 'no topic set'
    expect(formatter.format()).toBe 'No topic set.'

  it "surrounds the message with perentheses if from the user", ->
    formatter.setContext 'ournick'
    formatter.setMessage 'no topic set'
    expect(formatter.format()).toBe '(No topic set)'

  it "replaces '#from' with the user who sent the message", ->
    formatter.setContext 'othernick'
    formatter.setMessage '#from set the topic'
    expect(formatter.format()).toBe 'othernick set the topic.'

  it "doesn't capitalise the first letter when it is a nick, even when the nick is 'you'", ->
    formatter.setContext 'you'
    formatter.setMessage '#from set the topic'
    expect(formatter.format()).toBe 'you set the topic.'

  it "replaces '#to' with the user who sent the message", ->
    formatter.setContext undefined, 'bob'
    formatter.setMessage '#to got kicked'
    expect(formatter.format()).toBe 'bob got kicked.'

  it "replaces '#what' with the user who sent the message", ->
    formatter.setContext undefined, undefined, 'this is the toipc'
    formatter.setMessage 'topic changed to: #what'
    expect(formatter.format()).toBe 'Topic changed to: this is the toipc.'

  it "replaces '#what' with the user who sent the message, even when the what field is '#to'", ->
    formatter.setContext 'othernick', 'bob', '#to'
    formatter.setMessage 'topic changed to: #what'
    expect(formatter.format()).toBe 'Topic changed to: #to.'

  it "replaces '#from', '#to' and '#what' when all are set", ->
    formatter.setContext 'othernick', 'bob', 'spamming /dance'
    formatter.setMessage '#from kicked #to for #what'
    expect(formatter.format()).toBe 'othernick kicked bob for spamming /dance.'

  it "replaces '#from' with you, when the user sent the message", ->
    formatter.setContext 'ournick', 'bob', 'spamming /dance'
    formatter.setMessage '#from kicked #to for #what'
    expect(formatter.format()).toBe '(You kicked bob for spamming /dance)'

  it "replaces '#to' with you, when the message pertains to the user", ->
    formatter.setContext 'othernick', 'ournick', 'spamming /dance'
    formatter.setMessage '#from kicked #to for #what'
    expect(formatter.format()).toBe 'othernick kicked you for spamming /dance.'

  it "initially only has styles from setCustomStyle()", ->
    expect(formatter.getStyle()).toBe 'purple'

  it "can have styles added", ->
    formatter.addStyle 'yellow'
    expect(formatter.getStyle()).toBe 'purple yellow'

  it "setting a style removes the added styles but keeps custom styles", ->
    formatter.addStyle 'yellow'
    formatter.setStyle 'blue'
    expect(formatter.getStyle()).toBe 'purple blue'

  it "uses the 'self' style when the message is from the user", ->
    formatter.setContext 'ournick'
    expect(formatter.getStyle()).toBe 'purple self'

  it "uses the 'self' style when the message pertains to the user", ->
    formatter.setContext undefined, 'ournick'
    expect(formatter.getStyle()).toBe 'purple self'

  it "doesn't uses the 'self' style when the message is from or pertains to another user", ->
    formatter.setContext 'othernick', 'bob'
    expect(formatter.getStyle()).toBe 'purple'

  it "uses clear() to reset state and format another message", ->
    formatter.setContext 'othernick', 'ournick', 'spamming /dance'
    formatter.setMessage '#from kicked #to for #what'
    formatter.addStyle 'black'
    formatter.clear()
    formatter.setContext 'ournick'
    formatter.setMessage '#from set the topic'
    expect(formatter.format()).toBe '(You set the topic)'
    expect(formatter.getStyle()).toBe 'purple self'

