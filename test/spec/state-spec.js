describe('circ.CircState', function() {
  var CircState = exports.CircState;
  var state;

  beforeEach(function() {
    state = new CircState({'nick': 'janedoe'});
    spyOn(state, 'onjoin');
    spyOn(state, 'onpart');
    spyOn(state, 'onnick');
    spyOn(state, 'onownnick');
  });

  it('has no channels by default', function() {
    expect(Object.keys(state.state.channels).length).toBe(0);
  });

  it('processes nick changes', function() {
    expect(state.state.nick).toBe('janedoe');
    state.process(':janedoe!address NICK :johndoe');
    expect(state.state.nick).toBe('johndoe');
    expect(state.onnick).toHaveBeenCalledWith('janedoe', 'johndoe');
    expect(state.onownnick).toHaveBeenCalledWith('johndoe');
  });

  it('processes nick changes', function() {
    expect(state.state.nick).toBe('janedoe');
    state.process(':notjanedoe!address NICK :johndoe');
    expect(state.state.nick).toBe('janedoe');
    expect(state.onnick).toHaveBeenCalledWith('notjanedoe', 'johndoe');
    expect(state.onownnick).not.toHaveBeenCalled();
  });

  describe('joined a channel', function() {
    beforeEach(function() {
      state.process(':janedoe!address JOIN :#test');
    });

    it('adds the channel', function() {
      expect(state.onjoin).toHaveBeenCalledWith('#test');
      expect(JSON.stringify(state.state.channels)).toBe(JSON.stringify({'#test': {}}))
    });

    it('removes a channel when the current user parts', function() {
      state.process(':janedoe!address PART :#test :janedoe');
      expect(state.onpart).toHaveBeenCalledWith('#test');
      expect(JSON.stringify(state.state.channels)).toBe(JSON.stringify({}))
    });

    it('does not remove a channel when a different user parts', function() {
      state.process(':notjanedoe!address PART :#test :notjanedoe');
      expect(state.onpart).not.toHaveBeenCalled();
      expect(JSON.stringify(state.state.channels)).toBe(JSON.stringify({'#test': {}}))
    });
  });

});