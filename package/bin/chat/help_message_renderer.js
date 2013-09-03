(function() {
  "use strict";
  var HelpMessageRenderer, exports, _base, _ref, _ref1;

  var exports = (_ref = (_base = ((_ref1 = window.chat) != null ? _ref1 : window.chat = {})).window) != null ? _ref : _base.window = {};

  /*
   * Displays help messages to the user, such as listing the available commands or
   * keyboard shortcuts.
   */
  HelpMessageRenderer = (function() {

    /*
     * The total width of the help message, in number of characters (excluding
     * spaces)
     */
    HelpMessageRenderer.TOTAL_WIDTH = 50;

    /*
     * The order that command categories are displayed to the user.
     */
    HelpMessageRenderer.CATEGORY_ORDER = ['common', 'uncommon', 'one_identity', 'scripts', 'misc'];

    HelpMessageRenderer.COMMAND_STYLE = 'notice help group';

    /*
     * @param {function(opt_message, opt_style)} postMessage
     */
    function HelpMessageRenderer(postMessage) {
      this._postMessage = postMessage;
      this._commands = {};
    }

    /*
     * Displays a help message for the given commands, grouped by category.
     * @param {Object.<string: {category: string}>} commands
     */


    HelpMessageRenderer.prototype.render = function(commands) {
      this._commands = commands;
      this._postMessage();
      this._printCommands();
      this._postMessage(html.escape("Type '/help <command>' to see details about a specific command."), 'notice help');
      return this._postMessage("Type '/hotkeys' to see the list of keyboard shortcuts.", 'notice help');
    };

    HelpMessageRenderer.prototype._printCommands = function() {
      var group, _i, _len, _ref2, _results;
      _ref2 = this._groupCommandsByCategory();
      _results = [];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        group = _ref2[_i];
        this._postMessage("" + (this._getCommandGroupName(group.category)) + " Commands:", HelpMessageRenderer.COMMAND_STYLE);
        this._postMessage();
        this._printCommandGroup(group.commands.sort());
        _results.push(this._postMessage());
      }
      return _results;
    };

    /*
     * @return {number} Returns the number of characters in the longest command.
     */
    HelpMessageRenderer.prototype._getMaxCommandLength = function() {
      var command, maxLength;
      maxLength = 0;
      for (command in this._commands) {
        if (command.length > maxLength) {
          maxLength = command.length;
        }
      }
      return maxLength;
    };

    /*
     * Returns a map of categories mapped to command names.
     * @return {Array.<{string: Array.<string>}>}
     */
    HelpMessageRenderer.prototype._groupCommandsByCategory = function() {
      var category, categoryToCommands, command, name, _ref2, _ref3, _ref4;
      categoryToCommands = {};
      _ref2 = this._commands;
      for (name in _ref2) {
        command = _ref2[name];
        if (command.category === 'hidden') {
          continue;
        }
        category = (_ref3 = command.category) != null ? _ref3 : 'misc';
        if ((_ref4 = categoryToCommands[category]) == null) {
          categoryToCommands[category] = [];
        }
        categoryToCommands[category].push(name);
      }
      return this._orderGroups(categoryToCommands);
    };

    /*
     * Given a map of categories to commands, order the categories in the order
     * we'd like to display to the user.
     * @param {Object.<string: Array.<string>>} categoryToCommands
     * @return {Array.<{category: string, commands: Array.<string>}>}
     */
    HelpMessageRenderer.prototype._orderGroups = function(categoryToCommands) {
      var category, groups, _i, _len, _ref2;
      groups = [];
      _ref2 = HelpMessageRenderer.CATEGORY_ORDER;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        category = _ref2[_i];
        groups.push({
          category: category,
          commands: categoryToCommands[category]
        });
      }
      return groups;
    };

    /*
     * Given a category, return the name to display to the user.
     * @param {string} category
     * @return {string}
     */
    HelpMessageRenderer.prototype._getCommandGroupName = function(category) {
      switch (category) {
        case 'common':
          return 'Basic IRC';
        case 'uncommon':
          return 'Other IRC';
        case 'one_identity':
          return 'One Identity';
        case 'scripts':
          return 'Script';
        default:
          return 'Misc';
      }
    };

    /*
     * Print an array of commands.
     * @param {Array.<string>} commands
     */
    HelpMessageRenderer.prototype._printCommandGroup = function(commands) {
      var command, i, isLastMessageInRow, line, _i, _len, _results;
      line = [];
      for (i = _i = 0, _len = commands.length; _i < _len; i = ++_i) {
        line.push('<span class="help-command">' + commands[i] + '</span>');
      }
      this._postMessage(line.join(''), HelpMessageRenderer.COMMAND_STYLE);
    };

    /*
     * Display a help message detailing the available hotkeys.
     * @param {Object.<string: {description: string, group: string,
     *     readableName: string}>} hotkeys
     */
    HelpMessageRenderer.prototype.renderHotkeys = function(hotkeys) {
      var groupsVisited, hotkeyInfo, id, name, _results;
      this._postMessage();
      this._postMessage("Keyboard Shortcuts:", 'notice help');
      this._postMessage();
      groupsVisited = {};
      _results = [];
      for (id in hotkeys) {
        hotkeyInfo = hotkeys[id];
        if (hotkeyInfo.group) {
          if (hotkeyInfo.group in groupsVisited) {
            continue;
          }
          groupsVisited[hotkeyInfo.group] = true;
          name = hotkeyInfo.group;
        } else {
          name = hotkeyInfo.readableName;
        }
        _results.push(this._postMessage("  " + name + ": " + hotkeyInfo.description, 'notice help'));
      }
      return _results;
    };

    return HelpMessageRenderer;

  })();

  exports.HelpMessageRenderer = HelpMessageRenderer;

}).call(this);
