describe 'A custom command parser', ->
  parser = undefined

  beforeEach ->
    parser = chat.customCommandParser

  it 'parses user input and returns an IRC command', ->
    result = parser.parse '#bash', ('kick sugarman "for spamming /dance"'.split ' ')...
    expect(result).toEqual ['KICK', '#bash', 'sugarman', 'for spamming /dance']

  describe 'that is merging quoted words', ->
    result = undefined

    merge = (text) ->
      result = parser._mergeQuotedWords (text.split ' ')

    it "doesn't change unquoted phrases", ->
      merge 'hello world'
      expect(result).toEqual 'hello world'.split ' '

    it "unquotes a single quoted argument", ->
      merge '"hi"'
      expect(result).toEqual ['hi']

    it "does nothing on an unmatched quote", ->
      merge 'sugarman "for spamming /dance'
      expect(result).toEqual 'sugarman "for spamming /dance'.split ' '

    it 'can merge arguments that are quoted', ->
      merge 'sugarman "for spamming /dance"'
      expect(result).toEqual ['sugarman', 'for spamming /dance']

      merge '"for spamming /dance" more args'
      expect(result).toEqual ['for spamming /dance', 'more', 'args']

      merge 'sugarman "for spamming /dance" more args'
      expect(result).toEqual ['sugarman', 'for spamming /dance', 'more', 'args']

    it 'can merge multiple sets of quoted arguments', ->
      merge 'sugarman "for spamming /dance" more args "this is one arg" last args'
      expect(result).toEqual [
        'sugarman', 'for spamming /dance', 'more', 'args',
        'this is one arg', 'last', 'args']