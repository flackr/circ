// Generated by CoffeeScript 1.4.0
(function() {
  "use strict";
  var Storage, exports, _ref,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  exports = (_ref = window.chat) != null ? _ref : window.chat = {};

  /*
   * Manages storage.
  */


  Storage = (function(_super) {

    __extends(Storage, _super);

    /*
       * Items loaded from sync storage related to the user's IRC state
    */


    Storage.STATE_ITEMS = ['nick', 'servers', 'channels', 'ignored_messages'];

    /*
       * Items loaded from sync storage on startup
    */


    Storage.INITIAL_ITEMS = ['password', 'server_device', 'autostart'];

    /*
       * Items loaded from local storage on startup
    */


    Storage.INITIAL_ITEMS_LOCAL = ['completed_walkthrough', 'scripts', 'loaded_prepackaged_scripts'];

    function Storage(chat) {
      this._restoreScripts = __bind(this._restoreScripts, this);

      this._onChanged = __bind(this._onChanged, this);
      Storage.__super__.constructor.apply(this, arguments);
      this._chat = chat;
      this._log = getLogger(this);
      this._scripts = [];
      this._channels = [];
      this._servers = [];
      this._nick = void 0;
      this._autostart = void 0;
      this.password = void 0;
      this.serverDevice = void 0;
      chrome.storage.onChanged.addListener(this._onChanged);
      this.pause();
    }

    /*
       * Save an object to sync storage for the script with the given name.
       * @param {string} name A unique name representing the script.
       * @param {Object} item The item to store.
    */


    Storage.prototype.saveItemForScript = function(name, item) {
      return this._store(this._getScriptStorageHandle(name), item);
    };

    /*
       * Load an object from sync storage for the script with the given name.
       * @param {string} name A unique name representing the script.
       * @param {function(Object)} onLoaded The function that is called once the item
       *     is loaded.
    */


    Storage.prototype.loadItemForScript = function(name, onLoaded) {
      var storageHandle,
        _this = this;
      storageHandle = this._getScriptStorageHandle(name);
      return chrome.storage.sync.get(storageHandle, function(state) {
        return onLoaded(state[storageHandle]);
      });
    };

    /*
       * Clears the item stored for the given script. This is called after a script
       * is uninstalled.
       * @param {string} name A unique name representing the script.
    */


    Storage.prototype.clearScriptStorage = function(name) {
      return chrome.storage.sync.remove(this._getScriptStorageHandle(name));
    };

    Storage.prototype._getScriptStorageHandle = function(name) {
      return 'script_' + name;
    };

    /*
       * Listen for storage changes.
       * If the password updated then change our own. If the password was cleared
       * then restore it.
    */


    Storage.prototype._onChanged = function(changeMap, areaName) {
      var change, script, _i, _len, _ref1, _results;
      if (changeMap.password) {
        this._onPasswordChange(changeMap.password);
      }
      if (changeMap.server_device) {
        this._onServerDeviceChange(changeMap.server_device);
      }
      _ref1 = this._scripts;
      _results = [];
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        script = _ref1[_i];
        change = changeMap[this._getScriptStorageHandle(script.getName())];
        if (change) {
          _results.push(this._chat.scriptHandler.storageChanged(script, change));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    Storage.prototype._onPasswordChange = function(passwordChange) {
      this._log('password changed from', passwordChange.oldValue, 'to', passwordChange.newValue);
      if (passwordChange.newValue === this.password) {
        return;
      }
      if (passwordChange.newValue) {
        this.password = passwordChange.newValue;
        return this._chat.setPassword(this.password);
      } else {
        this._log('password was cleared. Setting password back to', this.password);
        return this._store('password', this.password);
      }
    };

    Storage.prototype._onServerDeviceChange = function(serverChange) {
      var _ref1, _ref2, _ref3, _ref4;
      this._log('device server changed from', (_ref1 = serverChange.oldValue) != null ? _ref1.addr : void 0, (_ref2 = serverChange.oldValue) != null ? _ref2.port : void 0, 'to', (_ref3 = serverChange.newValue) != null ? _ref3.addr : void 0, (_ref4 = serverChange.newValue) != null ? _ref4.port : void 0);
      if (serverChange.newValue) {
        this.serverDevice = serverChange.newValue;
        return this._chat.remoteConnectionHandler.determineConnection(this.serverDevice);
      } else if (this.serverDevice) {
        return this._store('server_device', this.serverDevice);
      }
    };

    /*
       * Stops storing state items (channel, server, nick).
       * This is used when the client is resuming it's IRC state and doesn't want
       * to make redudant writes to storage.
    */


    Storage.prototype.pause = function() {
      return this._paused = true;
    };

    Storage.prototype.resume = function() {
      return this._paused = false;
    };

    Storage.prototype.setAutostart = function(opt_enabled) {
      var enabled;
      enabled = opt_enabled != null ? opt_enabled : !this._autostart;
      this._autostart = enabled;
      this._store('autostart', enabled);
      return this._autostart;
    };

    Storage.prototype.finishedWalkthrough = function() {
      return this._store('completed_walkthrough', true, 'local');
    };

    Storage.prototype.finishedLoadingPrepackagedScripts = function() {
      return this._store('loaded_prepackaged_scripts', true, 'local');
    };

    Storage.prototype.nickChanged = function(nick) {
      if (this._nick === nick) {
        return;
      }
      this._nick = nick;
      return this._store('nick', nick);
    };

    Storage.prototype.channelJoined = function(server, name, type, key) {
      var chan, channelObj, i, _i, _len, _ref1;
      if (type == null) {
        type = 'normal';
      }
      _ref1 = this._channels;
      for (i = _i = 0, _len = _ref1.length; _i < _len; i = ++_i) {
        chan = _ref1[i];
        if (chan.server === server && chan.name === name) {
          if (chan.key !== key) {
            this._channels.splice(i, 1);
            break;
          }
          return;
        }
      }
      channelObj = {
        server: server,
        name: name,
        key: key
      };
      if (type !== 'normal') {
        channelObj.type = type;
      }
      this._channels.push(channelObj);
      return this._store('channels', this._channels);
    };

    Storage.prototype.serverJoined = function(name, port, password) {
      if (this._isDuplicateServer(name, port)) {
        return;
      }
      this._servers.push({
        name: name,
        port: port,
        password: password
      });
      return this._store('servers', this._servers);
    };

    Storage.prototype._isDuplicateServer = function(name, port) {
      var i, server, _i, _len, _ref1;
      _ref1 = this._servers;
      for (i = _i = 0, _len = _ref1.length; _i < _len; i = ++_i) {
        server = _ref1[i];
        if (server.name === name) {
          if (server.port === port) {
            return true;
          }
          this._servers.splice(i, 1);
          break;
        }
      }
      return false;
    };

    Storage.prototype.parted = function(server, channel) {
      if (channel != null) {
        return this._channelParted(server, channel);
      } else {
        return this._serverParted(server);
      }
    };

    Storage.prototype._channelParted = function(server, name) {
      var channel, i, _i, _len, _ref1;
      _ref1 = this._channels;
      for (i = _i = 0, _len = _ref1.length; _i < _len; i = ++_i) {
        channel = _ref1[i];
        if (channel.server == server && channel.name.toLowerCase() == name.toLowerCase()) {
          this._channels.splice(i, 1);
          break;
        }
      }
      return this._store('channels', this._channels);
    };

    Storage.prototype._serverParted = function(name) {
      var i, server, _i, _len, _ref1;
      _ref1 = this._servers;
      for (i = _i = 0, _len = _ref1.length; _i < _len; i = ++_i) {
        server = _ref1[i];
        if (server.name == name) {
          this._servers.splice(i, 1);
          break;
        }
      }
      return this._store('servers', this._servers);
    };

    Storage.prototype.ignoredMessagesChanged = function() {
      return this._store('ignored_messages', this._getIgnoredMessages());
    };

    Storage.prototype._getIgnoredMessages = function() {
      return this._chat.messageHandler.getIgnoredMessages();
    };

    Storage.prototype.scriptAdded = function(script) {
      if (this._isDuplicateScript(script)) {
        return;
      }
      this._scripts.push(script);
      return this._store('scripts', this._scripts, 'local');
    };

    Storage.prototype.scriptRemoved = function(scriptToRemove) {
      var i, script, _i, _len, _ref1;
      _ref1 = this._scripts;
      for (i = _i = 0, _len = _ref1.length; _i < _len; i = ++_i) {
        script = _ref1[i];
        if (script.id === scriptToRemove.id) {
          this._scripts.splice(i, 1);
          this._store('scripts', this._scripts, 'local');
          return;
        }
      }
    };

    Storage.prototype._isDuplicateScript = function(newScript) {
      var script, _i, _len, _ref1;
      _ref1 = this._scripts;
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        script = _ref1[_i];
        if (newScript.id === script.id) {
          return true;
        }
      }
    };

    Storage.prototype._store = function(key, value, type) {
      var storageObj;
      if (type == null) {
        type = 'sync';
      }
      if (!this.shouldStore(key)) {
        return;
      }
      this._log('storing', key, '=>', value, 'to', type);
      storageObj = {};
      storageObj[key] = value;
      if (type === 'sync') {
        return chrome.storage.sync.set(storageObj);
      } else {
        return chrome.storage.local.set(storageObj);
      }
    };

    Storage.prototype.shouldStore = function(key) {
      return !(this._paused && __indexOf.call(Storage.STATE_ITEMS, key) >= 0);
    };

    Storage.prototype.getState = function() {
      return {
        ircStates: this._createIRCStates(),
        servers: this._servers,
        channels: this._channels,
        nick: this._nick,
        ignoredMessages: this._getIgnoredMessages()
      };
    };

    Storage.prototype._createIRCStates = function() {
      var conn, ircStates, name, _ref1;
      ircStates = [];
      _ref1 = this._chat.connections;
      for (name in _ref1) {
        conn = _ref1[name];
        ircStates.push({
          server: conn.name,
          state: conn.irc.state,
          channels: conn.irc.channels,
          away: conn.irc.away,
          nick: conn.irc.nick
        });
      }
      return ircStates;
    };

    /*
       * Load initial items, such as whether to show the walkthrough.
    */


    Storage.prototype.init = function() {
      var _this = this;
      return chrome.storage.local.get(Storage.INITIAL_ITEMS_LOCAL, function(state) {
        _this._initializeLocalItems(state);
        return chrome.storage.sync.get(Storage.INITIAL_ITEMS, function(state) {
          _this._initializeSyncItems(state);
          return _this.emit('initialized');
        });
      });
    };

    Storage.prototype._initializeSyncItems = function(state) {
      this._state = state;
      this._restorePassword();
      this._loadServerDevice();
      return this._autostart = state.autostart;
    };

    Storage.prototype._initializeLocalItems = function(state) {
      this.completedWalkthrough = state['completed_walkthrough'];
      this.loadedPrepackagedScripts = state['loaded_prepackaged_scripts'];
      return this._restoreScripts(state);
    };

    Storage.prototype._restoreScripts = function(state) {
      var _this = this;
      if (!state.scripts) {
        return;
      }
      this._log(state.scripts.length, 'scripts loaded from storage:', state.scripts);
      return script.loader.loadScriptsFromStorage(state.scripts, function(script) {
        _this._scripts.push(script);
        return _this._chat.scriptHandler.addScript(script);
      });
    };

    Storage.prototype.restoreSavedState = function(opt_callback) {
      var _this = this;
      return chrome.storage.sync.get(Storage.STATE_ITEMS, function(savedState) {
        _this.loadState(savedState);
        return typeof opt_callback === "function" ? opt_callback() : void 0;
      });
    };

    Storage.prototype.loadState = function(state) {
      this._state = state;
      this._restoreNick();
      this._restoreServers();
      this._restoreChannels();
      this._restoreIgnoredMessages();
      this._restoreIRCStates();
      return this._markItemsAsLoaded(Storage.STATE_ITEMS, state);
    };

    Storage.prototype._restorePassword = function() {
      this.password = this._state.password;
      if (!this.password) {
        this.password = irc.util.randomName();
        this._log('no password found, setting new password to', this.password);
        this._store('password', this.password);
      } else {
        this._log('password loaded from storage:', this.password);
      }
      this._chat.setPassword(this.password);
      return this._chat.remoteConnectionHandler.determineConnection();
    };

    Storage.prototype._restoreServers = function() {
      var server, servers, _i, _len, _results;
      if (!(servers = this._state.servers)) {
        return;
      }
      this._servers = servers;
      _results = [];
      for (_i = 0, _len = servers.length; _i < _len; _i++) {
        server = servers[_i];
        _results.push(this._chat.connect(server.name, server.port, server.password));
      }
      return _results;
    };

    Storage.prototype._restoreChannels = function() {
      var channel, channels, conn, _i, _len, _results;
      if (!(channels = this._state.channels)) {
        return;
      }
      this._channels = channels;
      _results = [];
      for (_i = 0, _len = channels.length; _i < _len; _i++) {
        channel = channels[_i];
        conn = this._chat.connections[channel.server];
        if (!conn) {
          continue;
        }
        if (channel.type === 'private') {
          _results.push(this._chat.createPrivateMessageWindow(conn, channel.name));
        } else {
          _results.push(this._chat.join(conn, channel.name, channel.key));
        }
      }
      return _results;
    };

    Storage.prototype._restoreIgnoredMessages = function() {
      var ignoredMessages;
      if (!(ignoredMessages = this._state['ignored_messages'])) {
        return;
      }
      this._log('restoring ignored messages from storage:', ignoredMessages);
      return this._chat.messageHandler.setIgnoredMessages(ignoredMessages);
    };

    Storage.prototype._restoreNick = function() {
      var nick;
      if (!((nick = this._state.nick) && typeof nick === 'string')) {
        return;
      }
      this._nick = nick;
      return this._chat.setNick(nick);
    };

    Storage.prototype._restoreIRCStates = function() {
      var conn, connectedServers, ircState, ircStates, _i, _len;
      if (!(ircStates = this._state.ircStates)) {
        return;
      }
      connectedServers = [];
      for (_i = 0, _len = ircStates.length; _i < _len; _i++) {
        ircState = ircStates[_i];
        conn = this._chat.connections[ircState.server];
        connectedServers.push(ircState.server);
        if (conn) {
          this._setIRCState(conn, ircState);
        }
      }
      return this._disconnectServersWithNoState(connectedServers);
    };

    Storage.prototype._disconnectServersWithNoState = function(connectedServers) {
      var conn, name, _ref1, _results;
      _ref1 = this._chat.connections;
      _results = [];
      for (name in _ref1) {
        conn = _ref1[name];
        if (__indexOf.call(connectedServers, name) < 0) {
          _results.push(conn.irc.state = 'disconnected');
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    /*
       * Loads servers, channels and nick from the given IRC state.
       * The state has the following format:
       * { nick: string, channels: Array.<{sevrer, name}>,
       *     servers: Array.<{name, port}>, irc_state: object,
       *     server_device: { port: number, addr: string}, password: string }
       * @param {Object} ircState An object that represents the current state of an IRC
       *##
       *     client.
       *##
    */


    Storage.prototype._setIRCState = function(conn, ircState) {
      var channelInfo, channelName, nick, nicks, norm, _ref1, _results;
      if (ircState.state === 'connected') {
        this._chat.onConnected(conn);
      }
      if (ircState.state) {
        conn.irc.state = ircState.state;
      }
      if (ircState.away) {
        conn.irc.away = ircState.away;
      }
      if (ircState.channels) {
        conn.irc.channels = ircState.channels;
      }
      conn.irc.nick = ircState.nick;
      if (!ircState.channels) {
        return;
      }
      _ref1 = ircState.channels;
      _results = [];
      for (channelName in _ref1) {
        channelInfo = _ref1[channelName];
        this._chat.onJoined(conn, channelName);
        nicks = (function() {
          var _ref2, _results1;
          _ref2 = channelInfo.names;
          _results1 = [];
          for (norm in _ref2) {
            nick = _ref2[norm];
            _results1.push(nick);
          }
          return _results1;
        })();
        _results.push(this._chat.onNames({
          context: {
            server: conn.name,
            channel: channelName
          }
        }, nicks));
      }
      return _results;
    };

    Storage.prototype._loadServerDevice = function() {
      this.loadedServerDevice = true;
      this.serverDevice = this._state.server_device;
      if (!this.serverDevice) {
        this._log('no remote server found', this._state);
      }
      if (this.serverDevice) {
        this._log('loaded server device', this.serverDevice);
      }
      return this._chat.remoteConnectionHandler.determineConnection();
    };

    /*
       * Marks that a certain item has been loaded from storage.
    */


    Storage.prototype._markItemsAsLoaded = function(items, state) {
      var item, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = items.length; _i < _len; _i++) {
        item = items[_i];
        _results.push(this["" + item + "Loaded"] = state[item] != null);
      }
      return _results;
    };

    Storage.prototype.becomeServerDevice = function(connectionInfo) {
      this.serverDevice = {
        addr: connectionInfo.addr,
        port: connectionInfo.port
      };
      return this._store('server_device', this.serverDevice);
    };

    return Storage;

  })(EventEmitter);

  exports.Storage = Storage;

}).call(this);
