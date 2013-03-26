// Generated by CoffeeScript 1.4.0
(function() {
  "use strict";
  var ChatLog, exports, _ref,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __slice = [].slice,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  exports = (_ref = window.chat) != null ? _ref : window.chat = {};

  /*
   * Keeps a running chat log.
  */


  ChatLog = (function() {

    ChatLog.MAX_ENTRIES_PER_SERVER = 1000;

    function ChatLog() {
      this.add = __bind(this.add, this);
      this._entries = {};
      this._whitelist = [];
    }

    /*
       * Returns a raw representation of the chat log which can be later serialized.
    */


    ChatLog.prototype.getData = function() {
      return this._entries;
    };

    /*
       * Load chat history from another chat log's data.
       * @param {Object.<Context, string>} serializedChatLog
    */


    ChatLog.prototype.loadData = function(serializedChatLog) {
      return this._entries = serializedChatLog;
    };

    ChatLog.prototype.whitelist = function() {
      var types;
      types = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this._whitelist = this._whitelist.concat(types);
    };

    ChatLog.prototype.add = function(context, types, content) {
      var entryList, _base, _ref1;
      if (!this._hasValidType(types.split(' '))) {
        return;
      }
      entryList = (_ref1 = (_base = this._entries)[context]) != null ? _ref1 : _base[context] = [];
      entryList.push(content);
      if (entryList.length > ChatLog.MAX_ENTRIES_PER_SERVER) {
        return entryList.splice(0, 25);
      }
    };

    ChatLog.prototype._hasValidType = function(types) {
      var type, _i, _len;
      for (_i = 0, _len = types.length; _i < _len; _i++) {
        type = types[_i];
        if (__indexOf.call(this._whitelist, type) >= 0) {
          return true;
        }
      }
      return false;
    };

    ChatLog.prototype.getContextList = function() {
      var context, _results;
      _results = [];
      for (context in this._entries) {
        _results.push(Context.fromString(context));
      }
      return _results;
    };

    ChatLog.prototype.get = function(context) {
      var _ref1;
      return (_ref1 = this._entries[context]) != null ? _ref1.join(' ') : void 0;
    };

    return ChatLog;

  })();

  exports.ChatLog = ChatLog;

}).call(this);
