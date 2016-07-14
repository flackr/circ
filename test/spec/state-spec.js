describe('circ.CircState', function() {
  var CircState = exports.CircState;
  var state;

  beforeEach(function() {
    state = new CircState({'nick': 'janedoe'});
    spyOn(state, 'onjoin');
    spyOn(state, 'onpart');
    spyOn(state, 'onnick');
    spyOn(state, 'onownnick');
    spyOn(state, 'onevent');
  });

  it('has no channels by default', function() {
    expect(Object.keys(state.state.channels).length).toBe(0);
  });

  it('processes nick changes', function() {
    expect(state.state.nick).toBe('janedoe');
    state.process(':janedoe!address NICK :johndoe', 0);
    expect(state.state.nick).toBe('johndoe');
    expect(state.onnick).toHaveBeenCalledWith('janedoe', 'johndoe');
    expect(state.onownnick).toHaveBeenCalledWith('johndoe');
  });

  it('processes nick changes', function() {
    expect(state.state.nick).toBe('janedoe');
    state.process(':notjanedoe!address NICK :johndoe', 0);
    expect(state.state.nick).toBe('janedoe');
    expect(state.onnick).toHaveBeenCalledWith('notjanedoe', 'johndoe');
    expect(state.onownnick).not.toHaveBeenCalled();
  });

  it('processes sent private messages', function() {
    state.processOutbound('PRIVMSG johndoe Hello John', 0);
    expect(state.onevent).toHaveBeenCalledWith('johndoe', jasmine.any(Object));
    var lastEvent = state.onevent.calls.mostRecent().args[1];
    expect(lastEvent.data).toBe('Hello John');
    expect(lastEvent.from).toBe('janedoe');
  });

  it('processes private messages from others', function() {
    state.process(':johndoe!address PRIVMSG janedoe :Hello Jane', 0);
    expect(state.onevent).toHaveBeenCalledWith('johndoe', jasmine.any(Object));
    var lastEvent = state.onevent.calls.mostRecent().args[1];
    expect(lastEvent.data).toBe('Hello Jane');
    expect(lastEvent.from).toBe('johndoe');
  });

  describe('joined a channel', function() {
    beforeEach(function() {
      state.process(':janedoe!address JOIN :#test', 0);
    });

    it('adds the channel', function() {
      expect(state.onjoin).toHaveBeenCalledWith('#test');
      expect(state.state.channels['#test']).toBeDefined();
    });

    it('removes a channel when the current user parts', function() {
      state.process(':janedoe!address PART :#test :janedoe', 0);
      expect(state.onpart).toHaveBeenCalledWith('#test');
      expect(state.state.channels['#test']).toBeUndefined();
    });

    it('does not remove a channel when a different user parts', function() {
      state.process(':notjanedoe!address PART :#test :notjanedoe', 0);
      expect(state.onpart).not.toHaveBeenCalled();
      expect(state.state.channels['#test']).toBeDefined();
    });
  });

});