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
    spyOn(state, 'onnames');
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
    state.processOutbound('PRIVMSG johndoe :Hello John', 0);
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
      state.process(':janedoe!address PART #test :janedoe', 0);
      expect(state.onpart).toHaveBeenCalledWith('#test');
      expect(state.state.channels['#test']).toBeUndefined();
    });

    it('does not remove a channel when a different user parts', function() {
      state.process(':notjanedoe!address PART #test :notjanedoe', 0);
      expect(state.onpart).not.toHaveBeenCalled();
      expect(state.state.channels['#test']).toBeDefined();
    });

    it('adds a new user to the user list when they join', function() {
      state.process(':johndoe!address JOIN :#test', 0);
      expect(state.state.channels['#test'].users).toEqual(['johndoe']);
    });

    it('removes a new user from the user list when they part', function() {
      state.process(':johndoe!address JOIN :#test', 0);
      expect(state.state.channels['#test'].users).toEqual(['johndoe']);
      state.process(':johndoe!address PART #test :johndoe', 0);
      expect(state.state.channels['#test'].users).toEqual([]);
    });

    it('processes names lists', function() {
      expect(state.state.channels['#test'].users).toEqual([]);
      state.process(':irc-address 353 janedoe = #test :janedoe johndoe');
      expect(state.state.channels['#test'].users).toEqual(['janedoe', 'johndoe']);
      state.process(':irc-address 353 janedoe = #test :flackr');
      expect(state.state.channels['#test'].users).toEqual(['janedoe', 'johndoe', 'flackr']);
    });

    it('processes end of names lists', function() {
      state.process(':irc-address 366 janedoe #test :End of NAMES list');
      expect(state.onnames).toHaveBeenCalledWith('#test');
    });

    it('clears the names list on NAMES command', function() {
      state.process(':irc-address 353 janedoe = #test :janedoe johndoe');
      expect(state.state.channels['#test'].users).toEqual(['janedoe', 'johndoe']);
      state.processOutbound('NAMES #test');
      expect(state.state.channels['#test'].users).toEqual([]);
    });
  });
});