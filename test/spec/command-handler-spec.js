describe('circ.UserCommandHandler', function() {
  var UserCommandHandler = circ.UserCommandHandler;
  var hostId = 'host';
  var server = 'server';
  var channel = '#test'
  var handler;

  beforeEach(function() {
    handler = new UserCommandHandler(new MockClient());
    handler.setActiveChannel(hostId, server, channel);
    spyOn(handler.client, 'send');
    spyOn(handler.client, 'join');
  });

  it ('ignores empty messages', function() {
    handler.runCommand('');
    expect(handler.client.send).not.toHaveBeenCalled();
    expect(handler.client.join).not.toHaveBeenCalled();
  });

  it('parses messages', function() {
    handler.runCommand('some user message');
    expect(handler.client.send).toHaveBeenCalledWith(hostId, server, 'PRIVMSG #test :some user message');
  });

  it('parses /join', function() {
    handler.runCommand('/join #test');
    expect(handler.client.join).toHaveBeenCalledWith(hostId, server, '#test');
  });

  it('fails to /join with an incorrect argument count', function() {
    expect(function() { handler.runCommand('/join'); }).toThrow(new Error('invalid command'));
    expect(function() { handler.runCommand('/join #foo bar'); }).toThrow(new Error('invalid command'));
  });
});