exports = window.chat ?= {}

##
# Walks first time users through the basics of CIRC.
#
# TODO: It would be awesome if this was implemented as a script.
##
class Walkthrough extends EventEmitter

  # Number of ms to wait after joining a server so the MTOD and other output can be displayed.
  @SERVER_OUTPUT_DELAY = 1000

  ##
  # @param {{getCurrentContext: function(), displayMessage: function()}}
  #     messageDisplayer
  # @param {Storage} storageState The current state of what's loaded from storage
  ##
  constructor: (messageDisplayer, storageState) ->
    super
    @_messageDisplayer = messageDisplayer
    @_steps = ['start', 'server', 'channel', 'end']
    @_findWalkthroughPoisition storageState
    @_beginWalkthrough()

  ##
  # Determine which step the user is on in the walkthrough. They may have left
  # half way through.
  ##
  _findWalkthroughPoisition: (storageState) ->
    if storageState.channelsLoaded
      @_currentStep = 3
    else if storageState.serversLoaded
      @_currentStep = 2
    else if storageState.nickLoaded
      @_currentStep = 1
    else
      @_currentStep = 0
    @_startingStep = @_currentStep


  ##
  # Based on where the user is in the walkthrough, determine the first message
  # the user sees.
  ##
  _beginWalkthrough: ->
    step = @_steps[@_currentStep]

    if step is 'end'
      @emit 'tear_down'
      return

    if step is 'channel'
      # Wait for the server to connect before displaying anything.
      @_currentStep--
      return
    @_displayStep step

  ##
  # @param {EventEmitter} ircEvents
  ##
  listenToIRCEvents: (ircEvents) ->
    ircEvents.on 'server', @_handleIRCEvent

  _handleIRCEvent: (event) =>
    @_context = event.context
    switch event.name
      when 'nick' then @_displayWalkthrough 'server'
      when 'connect' then @_displayWalkthrough 'channel'
      when 'joined' then @_displayWalkthrough 'end'

  _displayWalkthrough: (type) ->
    position = @_steps.indexOf type
    if position > @_currentStep
      @_currentStep = position
      @_displayStep type

  _displayStep: (name) ->
    this["_#{name}Walkthrough"] @_context ? @_messageDisplayer.getCurrentContext()

  _isFirstMessage: ->
    @_currentStep is @_startingStep

  ##
  # Display a message to the user.
  ##
  _message: (msg, style='system') ->
    context = @_messageDisplayer.getCurrentContext()
    @_messageDisplayer.displayMessage style, context, msg

  _startWalkthrough: ->
    @_message "To get started, set your nickname with /nick <my_nick>."

  _serverWalkthrough: ->
    if @_isFirstMessage()
      @_message "Join a server by typing /server <server> [port]."
    else
      @_message "Great! Now join a server by typing /server <server> [port]."
    @_message "For example, you can connect to freenode by typing " +
        "/server irc.freenode.net."

  _channelWalkthrough: (context) ->
    # Display after a delay to allow for MOTD and other output to be displayed.
     setTimeout (=> @_displayChannelWalkthough context), Walkthrough.SERVER_OUTPUT_DELAY

  _displayChannelWalkthough: (context) ->
    @_message "You've successfully connected to #{context.server}."
    @_message "Join a channel with /join <#channel>."

  _endWalkthrough: (context) ->
    unless @_isFirstMessage()
      @_message "Awesome, you've connected to #{context.channel}."
    @_message "If you're ever stuck, type /help to see a list of all commands."
    @_message "You can switch windows with alt+[0-9] or click in the channel " +
         "list on the left."
    @emit 'tear_down'

exports.Walkthrough = Walkthrough