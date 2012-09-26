describe 'Auto complete', ->
  ac = undefined

  beforeEach ->
    ac = new AutoComplete

  it 'auto-completes the given stub into a matching full length word', ->
    ac.setCompletions ['hi', 'bye']
    expect(ac.getCompletion 'h').toBe 'hi'

  it 'returns the stub on getCompletion() when no completions match', ->
    ac.setCompletions ['bourjeu', 'bye']
    expect(ac.getCompletion 'h').toBe 'h'

  it 'returns the stub on getCompletion() when no completions have been added', ->
    expect(ac.getCompletion 'hello').toBe 'hello'

  it 'returns the same completion when there is only one match', ->
    ac.setCompletions ['hello', 'bye']
    expect(ac.getCompletion 'hello').toBe 'hello'
    expect(ac.getCompletion()).toBe 'hello'
    expect(ac.getCompletion()).toBe 'hello'

  it 'cycles through possible matches on each getCompletion()', ->
    ac.setCompletions ['hi', 'hello', 'bye', 'help']
    expect(ac.getCompletion 'h').toBe 'hi'
    expect(ac.getCompletion()).toBe 'hello'
    expect(ac.getCompletion()).toBe 'help'
    expect(ac.getCompletion()).toBe 'hi'
    expect(ac.getCompletion()).toBe 'hello'
    expect(ac.getCompletion()).toBe 'help'
    expect(ac.getCompletion()).toBe 'hi'

  it 'uses only the first stub passed into getCompletion() until reset() is called', ->
    ac.setCompletions ['hi', 'bye', 'help', 'bee']
    expect(ac.getCompletion 'h').toBe 'hi'
    expect(ac.getCompletion 'bye').toBe 'help'
    expect(ac.getCompletion 'b').toBe 'hi'
    ac.reset()
    expect(ac.getCompletion 'b').toBe 'bye'
    expect(ac.getCompletion 'hi').toBe 'bee'
    expect(ac.getCompletion 'h').toBe 'bye'

  it 'ignores case if the stub has no caps', ->
    ac.setCompletions ['Hi', 'heLLo', 'help']
    expect(ac.getCompletion 'h').toBe 'Hi'
    expect(ac.getCompletion()).toBe 'heLLo'
    expect(ac.getCompletion()).toBe 'help'

  it 'does not ignore case if the stub contains one or more capital letter', ->
    ac.setCompletions ['Hi', 'heLLo', 'help']
    expect(ac.getCompletion 'H').toBe 'Hi'
    expect(ac.getCompletion 'H').toBe 'Hi'