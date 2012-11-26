describe "Util provides the following functions:", ->
  class TestClass1
  class TestClass2

  describe "truncateIfTooLarge", ->

    it "does nothing if the length of the text is less then the given max size", ->
      expect(truncateIfTooLarge 'puppy', 5).toBe 'puppy'
      expect(truncateIfTooLarge '', 100).toBe ''

    it "truncates the text and appends a suffix if the length text of the text
        is greater then the max size", ->
      expect(truncateIfTooLarge 'puppy', 4).toBe 'p...'
      expect(truncateIfTooLarge 'sally had a little lamb', 10).toBe 'sally h...'

    it "can have the suffix changed", ->
      expect(truncateIfTooLarge 'puppy', 4, '!').toBe 'pup!'

  describe "pluralize", ->

    it "does nothing if there is one of something", ->
      expect(pluralize 'dog', 1).toBe 'dog'
      expect(pluralize 'stress', 1).toBe 'stress'

    it "adds an 's' when there is 0 or > 1 of something", ->
      expect(pluralize 'cat', 2).toBe 'cats'
      expect(pluralize 'cat', 0).toBe 'cats'

    it "adds an 'es' when there is 0 or > 1 of something and the word ends in 's'", ->
      expect(pluralize 'stress', 2).toBe 'stresses'

  describe "getLogger", ->

    it "logs debug info", ->
      spyOn(window.console, 'log')
      spyOn(window.console, 'error')
      spyOn(window.console, 'warn')

      a = new TestClass1
      b = new TestClass2
      logA = getLogger a
      logB = getLogger b

      logA 'this is my message!'
      logB 'w', 'warning', 5, 'is a great number'
      logA 'e', 'error!', 'error msg'

      expect(console.log).toHaveBeenCalledWith 'TestClass1:', 'this is my message!'
      expect(console.warn).toHaveBeenCalledWith 'TestClass2:', 'warning', 5, 'is a great number'
      expect(console.error).toHaveBeenCalledWith 'TestClass1:', 'error!', 'error msg'

  describe "capitalizeString", ->

    it "capitalizes the first letter of words", ->
      expect(capitalizeString 'bob').toBe 'Bob'
      expect(capitalizeString 'BILL').toBe 'BILL'
      expect(capitalizeString '').toBe ''