describe "Util", ->
  class TestClass1
  class TestClass2

  it "logs debug info with log()", ->
    spyOn(window.console, 'log')
    spyOn(window.console, 'error')
    spyOn(window.console, 'warn')

    a = new TestClass1
    b = new TestClass2
    log a, 'this is my message!'
    log b, 'w', 'warning', 5, 'is a great number'
    log a, 'e', 'error!', 'error msg'

    expect(console.log).toHaveBeenCalledWith 'TestClass1:', 'this is my message!'
    expect(console.warn).toHaveBeenCalledWith 'TestClass2:', 'warning', 5, 'is a great number'
    expect(console.error).toHaveBeenCalledWith 'TestClass1:', 'error!', 'error msg'
