##
# This class provides convenience functions for scripts which make talking to
# the IRC client easier.
##

addEventListener 'message', (e) =>
  @onMessage(e.data) if typeof @onMessage is 'function'

##
# Set the name of the script. This is the name displayed in /scripts and used with /uninstall.
# @param {string} name
##
@setName = (name) ->
  @send 'meta', 'name', name

@setDescription = (description) ->
  # TODO

##
# Retrieve the script's saved information, if any, from sync storage.
##
@loadFromStorage = ->
  @send {}, 'storage', 'load'

##
# Save the script's information to sync storage.
# @param {Object} item The item to save to storage.
##
@saveToStorage = (item) ->
  @send {}, 'storage', 'save', item

##
# Send a message to the IRC server or client.
# @param {{server: string, channel: string}=} Specifies which room the event
#     takes place in. Events like registering to handle a command don't need
#     a context.
# @param {string} type The type of event (e.g. command, message, etc)
# @param {string} name The sub-type of the event (e.g. the type of command or
#     message)
# @param {Object...} args A variable number of arguments for the event.
##
@send = (opt_context, type, name, args...) ->
  if typeof opt_context is 'string' # no context
    args = [name].concat(args)
    name = type
    type = opt_context
    context = {}
  else
    context = opt_context
  event = {context, type, name, args}
  window.parent.postMessage(event, '*')

@propagate = (event, propagation='all') ->
  @send event.context, 'propagate', propagation, event.id
