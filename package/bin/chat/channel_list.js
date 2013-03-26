// Generated by CoffeeScript 1.4.0
(function() {
  "use strict";
  var ChannelList, exports, _ref,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  exports = (_ref = window.chat) != null ? _ref : window.chat = {};

  /*
   * A list of servers and channels to which the user is connected.
  */


  ChannelList = (function(_super) {

    __extends(ChannelList, _super);

    function ChannelList() {
      this._handleClick = __bind(this._handleClick, this);
      ChannelList.__super__.constructor.apply(this, arguments);
      this.$surface = $('#rooms-container .rooms');
      this.roomsByServer = {};
    }

    ChannelList.prototype.select = function(server, channel) {
      this._removeLastSelected();
      this._addClass(server, channel, 'selected');
      this._removeClass(server, channel, 'activity');
      return this._removeClass(server, channel, 'mention');
    };

    ChannelList.prototype._removeLastSelected = function() {
      var _ref1;
      return (_ref1 = $('.room.selected', this.$surface)) != null ? _ref1.removeClass('selected') : void 0;
    };

    ChannelList.prototype.activity = function(server, opt_channel) {
      return this._addClass(server, opt_channel, 'activity');
    };

    ChannelList.prototype.mention = function(server, opt_channel) {
      return this._addClass(server, opt_channel, 'mention');
    };

    ChannelList.prototype.remove = function(server, opt_channel) {
      if (opt_channel != null) {
        return this.roomsByServer[server].channels.remove(opt_channel);
      } else {
        this.roomsByServer[server].html.remove();
        return delete this.roomsByServer[server];
      }
    };

    ChannelList.prototype.insertChannel = function(i, server, channel) {
      this.roomsByServer[server].channels.insert(i, channel);
      return this.disconnect(server, channel);
    };

    ChannelList.prototype.addServer = function(serverName) {
      var channels, html, server;
      html = this._createServerHTML(serverName);
      server = $('.server', html);
      channels = this._createChannelList(html);
      this._handleMouseEvents(serverName, server, channels);
      this.roomsByServer[serverName.toLowerCase()] = {
        html: html,
        server: server,
        channels: channels
      };
      return this.disconnect(serverName);
    };

    ChannelList.prototype._createServerHTML = function(serverName) {
      var html;
      html = $('#templates .server-channels').clone();
      $('.server .content-item', html).text(serverName);
      this.$surface.append(html);
      return html;
    };

    ChannelList.prototype._createChannelList = function(html) {
      var channelList, channelTemplate;
      channelTemplate = $('#templates .channel');
      channelList = new chat.HTMLList($('.channels', html), channelTemplate);
      return channelList;
    };

    ChannelList.prototype._handleMouseEvents = function(serverName, server, channels) {
      var _this = this;
      server.mousedown(function() {
        return _this._handleClick(serverName);
      });
      return channels.on('clicked', function(channelName) {
        return _this._handleClick(serverName, channelName);
      });
    };

    ChannelList.prototype.disconnect = function(server, opt_channel) {
      return this._addClass(server, opt_channel, 'disconnected');
    };

    ChannelList.prototype.connect = function(server, opt_channel) {
      return this._removeClass(server, opt_channel, 'disconnected');
    };

    ChannelList.prototype._addClass = function(server, channel, c) {
      if (channel != null) {
        return this.roomsByServer[server].channels.addClass(channel.toLowerCase(), c);
      } else {
        return this.roomsByServer[server].server.addClass(c);
      }
    };

    ChannelList.prototype._removeClass = function(server, channel, c) {
      if (channel != null) {
        return this.roomsByServer[server].channels.removeClass(channel.toLowerCase(), c);
      } else {
        return this.roomsByServer[server].server.removeClass(c);
      }
    };

    ChannelList.prototype._handleClick = function(server, channel) {
      return this.emit('clicked', server, channel);
    };

    return ChannelList;

  })(EventEmitter);

  exports.ChannelList = ChannelList;

}).call(this);
