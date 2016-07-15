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
    spyOn(handler.client, 'connect');
  });

  it ('ignores empty messages', function() {
    handler.runCommand('');
    expect(handler.client.send).not.toHaveBeenCalled();
    expect(handler.client.join).not.toHaveBeenCalled();
  });

  it('parses /raw', function() {
    handler.runCommand('/raw some raw IRC command');
    expect(handler.client.send).toHaveBeenCalledWith(hostId, server, 'some raw IRC command');
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
    expect(function() { handler.runCommand('/join'); }).toThrow(new Error('Invalid command: Too few arguments'));
    expect(function() { handler.runCommand('/join #foo bar'); }).toThrow(new Error('Invalid command: Too many arguments'));
  });

  it('parses /part', function() {
    handler.runCommand('/part Goodbye everyone!');
    expect(handler.client.send).toHaveBeenCalledWith(hostId, server, 'PART #test Goodbye everyone!');
  });

  it('parses /server', function() {
    handler.runCommand('/server address port password');
    expect(handler.client.connect).toHaveBeenCalledWith(hostId, 'address', 'port', {'password': 'password'});
  });
});