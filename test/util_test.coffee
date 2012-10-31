describe "Util", ->
  class TestClass1
  class TestClass2

  it "logs debug info with function returned by getLogger()", ->
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

  it "capitalizes strings with capitalizeString()", ->
    expect(capitalizeString 'bob').toBe 'Bob'
    expect(capitalizeString 'BILL').toBe 'BILL'
    expect(capitalizeString '').toBe ''