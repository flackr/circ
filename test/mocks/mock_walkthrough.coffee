exports = window.mocks ?= {}

##
# Used to spy on walkthrough events.
##
class Walkthrough extends chat.Walkthrough

  @useMock: ->
    chat.Walkthrough = Walkthrough
    @instance = undefined

  @setInstance: (@instance) ->
    spyOn @instance, '_startWalkthrough'
    spyOn @instance, '_serverWalkthrough'
    spyOn @instance, '_channelWalkthrough'
    spyOn @instance, '_endWalkthrough'

  constructor: (args...) ->
    Walkthrough.setInstance this
    super args...

exports.Walkthrough = Walkthrough
