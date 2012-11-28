describe "A message formatter", ->
  formatter = undefined

  beforeEach ->
    formatter = new chat.MessageFormatter
    formatter.setNick 'ournick'
    formatter.setCustomStyle ['purple']

  it "adds a period to the end of the message", ->
    formatter.setMessage 'No topic set'
    expect(formatter.format()).toBe 'No topic set.'

  it "capitalises the first letter of the message", ->
    formatter.setMessage 'no topic set'
    expect(formatter.format()).toBe 'No topic set.'

  it "surrounds the message with perentheses if it's from the user", ->
    formatter.setContext 'ournick'
    formatter.setMessage 'no topic set'
    expect(formatter.format()).toBe '(No topic set)'

  it "returns an empty string when no message has been set", ->
    expect(formatter.format()).toBe ''

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

  it "replaces '#content' with the user who sent the message", ->
    formatter.setContext undefined, undefined, 'this is the toipc'
    formatter.setMessage 'topic changed to: #content'
    expect(formatter.format()).toBe 'Topic changed to: this is the toipc.'

  it "can have the content field set directly", ->
    formatter.setContent 'this is the toipc'
    formatter.setMessage 'topic changed to: #content'
    expect(formatter.format()).toBe 'Topic changed to: this is the toipc.'

  it "replaces '#content' with the user who sent the message, even when the content field is '#to'", ->
    formatter.setContext 'othernick', 'bob', '#to'
    formatter.setMessage 'topic changed to: #content'
    expect(formatter.format()).toBe 'Topic changed to: #to.'

  it "replaces '#from', '#to' and '#content' when all are set", ->
    formatter.setContext 'othernick', 'bob', 'spamming /dance'
    formatter.setMessage '#from kicked #to for #content'
    expect(formatter.format()).toBe 'othernick kicked bob for spamming /dance.'

  it "replaces '#from' with you, when the user sent the message", ->
    formatter.setContext 'ournick', 'bob', 'spamming /dance'
    formatter.setMessage '#from kicked #to for #content'
    expect(formatter.format()).toBe '(You kicked bob for spamming /dance)'

  it "replaces '#to' with you, when the message pertains to the user", ->
    formatter.setContext 'othernick', 'ournick', 'spamming /dance'
    formatter.setMessage '#from kicked #to for #content'
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

  it "can check if it has a certain style", ->
    formatter.addStyle 'black'
    expect(formatter.hasStyle 'purple').toBe true
    expect(formatter.hasStyle 'black').toBe true
    expect(formatter.hasStyle 'blue').toBe false

  it "can force the message to be from the user even when the from field doesn't match", ->
    formatter.setContext 'othernick', 'bob'
    formatter.setMessage '#from can be called #to'
    formatter.setFromUs(true)
    expect(formatter.format()).toBe '(You can be called bob)'
    expect(formatter.getStyle()).toBe 'purple self'

  it "can force the message not to pertain to the user even when the to field matches", ->
    formatter.setContext 'ournick', 'ournick'
    formatter.setMessage '#from can be called #to'
    formatter.setToUs(false)
    expect(formatter.format()).toBe '(You can be called ournick)'
    expect(formatter.getStyle()).toBe 'purple self'

  it "changes 'you is' to 'you are'", ->
    formatter.setContext 'ournick', 'ournick'
    formatter.setMessage '#from is cool; #to is the best'
    expect(formatter.format()).toBe '(You are cool; you are the best)'

  it "changes 'you has' to 'you have'", ->
    formatter.setContext 'ournick'
    formatter.setMessage '#from has a dog'
    expect(formatter.format()).toBe '(You have a dog)'

  it "can optionally not use pretty formatting", ->
    formatter.setContext 'ournick'
    formatter.setMessage '#from set the topic'
    formatter.setPrettyFormat false
    expect(formatter.format()).toBe 'you set the topic'

  it "only adds punctuation if the message ends in a character or number", ->
    formatter.setContent 'This is the topic!!!!'
    formatter.setMessage '#content'
    expect(formatter.format()).toBe 'This is the topic!!!!'

  it "uses clear() to reset state and format another message", ->
    formatter.setContext 'othernick', 'ournick', 'spamming /dance'
    formatter.setMessage '#from kicked #to for #content'
    formatter.addStyle 'black'
    formatter.setPrettyFormat false
    formatter.clear()
    formatter.setContext 'ournick'
    formatter.setMessage '#from set the topic'
    expect(formatter.format()).toBe '(You set the topic)'
    expect(formatter.getStyle()).toBe 'purple self'