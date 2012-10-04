describe 'A nick mentioned notifier', ->
  notification = chat.NickMentionedNotification

  it 'should notify when nick is mentioned', ->
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe')).toBe true
    expect(notification.shouldNotify('thragtusk', 'thragtusk')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'bill and sallyjoe and thragtusk')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'bobsallyjoe is a sallyjoe of sorts')).toBe true

  it 'should be case insensitive ', ->
    expect(notification.shouldNotify('sallyjoe', 'Sallyjoe')).toBe true
    expect(notification.shouldNotify('thragtusk', 'tHrAgTuSk')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'bill and SALLYJOE and thragtusk')).toBe true

  it 'should notify when there is trailing punctuation', ->
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe!')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe?')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe!?!?!!!!??')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe*')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe:')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe;')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe-')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe~')).toBe true
    expect(notification.shouldNotify('sallyjoe', "oh, it's sallyjoe...")).toBe true
    expect(notification.shouldNotify('sallyjoe', 'bye sallyjoe.')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'ssssallyjoe! Sallyjoe, you there?')).toBe true

  it 'should notify when there is a preceding @', ->
    expect(notification.shouldNotify('sallyjoe', '@sallyjoe, look at this!')).toBe true

  it 'should notify when there is a preceding ,', ->
    expect(notification.shouldNotify('sallyjoe', 'thragtusk,sallyjoe,joe: come to my desk')).toBe true

  it 'should notify with variable preceding and trailing whitespace', ->
     expect(notification.shouldNotify('sallyjoe', 'sallyjoe     ')).toBe true
     expect(notification.shouldNotify('sallyjoe', '     sallyjoe')).toBe true
     expect(notification.shouldNotify('sallyjoe', '     sallyjoe     ')).toBe true

  it 'should notify with combinations of @, punctuation and whitespace', ->
    expect(notification.shouldNotify('sallyjoe', 'I mean @sallyjoe*')).toBe true
    expect(notification.shouldNotify('sallyjoe', 'oh its @sallyjoe!!??  ')).toBe true

  it 'should not notify when nick is not mentioned', ->
    expect(notification.shouldNotify('thragtusk', 'sallyjoe')).toBe false
    expect(notification.shouldNotify('sallyjoe', '-sallyjoe-')).toBe false
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe::')).toBe false
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe--')).toBe false
    expect(notification.shouldNotify('sallyjoe', 'asallyjoe')).toBe false
    expect(notification.shouldNotify('sallyjoe', 'sallyjoea')).toBe false
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe!?!;')).toBe false
    expect(notification.shouldNotify('sallyjoe', '@@sallyjoe')).toBe false
    expect(notification.shouldNotify('sallyjoe', '#sallyjoe')).toBe false
    expect(notification.shouldNotify('sallyjoe', '#nick#')).toBe false
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe#')).toBe false
    expect(notification.shouldNotify('sallyjoe', 'sallyjoesallyjoe')).toBe false
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe1')).toBe false
    expect(notification.shouldNotify('sallyjoe', '1sallyjoe')).toBe false

  it 'should match with optional underscores', ->
    expect(notification.shouldNotify('sallyjoe', 'sallyjoe______')).toBe true
    expect(notification.shouldNotify('sallyjoe', '@sallyjoe_... you there?')).toBe true
    expect(notification.shouldNotify('sallyjoe__', 'sallyjoe')).toBe true
    expect(notification.shouldNotify('sallyjoe____', 'sallyjoe_')).toBe true