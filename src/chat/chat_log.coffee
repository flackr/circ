exports = window.chat ?= {}

##
# Keeps a running chat log.
##
class ChatLog

  @MAX_ENTRIES_PER_SERVER = 1000

  constructor: ->
    @_entries = {}
    @_whitelist = []

  ##
  # Returns a raw representation of the chat log which can be later serialized.
  ##
  getData: ->
    @_entries

  ##
  # Load chat history from another chat log's data.
  # @param {Object.<Context, string>} serializedChatLog
  ##
  loadData: (serializedChatLog) ->
    @_entries = serializedChatLog

  whitelist: (types...) ->
    @_whitelist = @_whitelist.concat types

  add: (context, types, content) =>
    return unless @_hasValidType types.split ' '
    entryList = @_entries[context] ?= []
    entryList.push content
    if entryList.length > ChatLog.MAX_ENTRIES_PER_SERVER
      entryList.splice 0, 25

  _hasValidType: (types) ->
    for type in types
      return true if type in @_whitelist
    false

  getContextList: ->
    (Context.fromString(context) for context of @_entries)

  get: (context) ->
    @_entries[context]?.join ' '

exports.ChatLog = ChatLog