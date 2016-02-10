(function() {
  "use strict";
  var exports, getLoggerForType,
    __slice = [].slice;

  var exports = window;

  exports.globals = {
    PROJECT_URL: 'http://flackr.github.com/circ',

    ISSUES_URL: 'https://github.com/flackr/circ/issues',

    // Should match the version in the manifest.
    VERSION: '0.6.7'
  };

  /*
   * determine API support
  */
  exports.api = {
    listenSupported: function() {
      return chrome.sockets && chrome.sockets.tcpServer;
    },
    clientSocketSupported: function() {
      return chrome.sockets && chrome.sockets.tcp;
    },
    getNetworkInterfacesSupported: function() {
      return chrome.system && chrome.system.network;
    }
  };

  /*
   * Download an asset at the given URL and a return a local url to it that can be
   * embeded in CIRC. A remote asset can not be directly embeded because of
   * packaged apps content security policy.
   * @param {string} url
   * @param {function(string)} The callback which is passed the new url
  */
  exports.getEmbedableUrl = function(url, onload) {
    var xhr;
    xhr = new XMLHttpRequest();
    xhr.open('GET', url);
    xhr.responseType = 'blob';
    xhr.onload = function(e) {
      return onload(window.webkitURL.createObjectURL(this.response));
    };
    xhr.onerror = function() {
      return console.error.apply(console, ['Failed to get embedable url for asset:', url].concat(__slice.call(arguments)));
    };
    return xhr.send();
  };

  /*
   * Returns a human readable representation of a list.
   * For example, [1, 2, 3] becomes "1, 2 and 3".
   * @param {Array.<Object>} array
   * @return {string}
  */
  exports.getReadableList = function(array) {
    var allButLastElement;
    if (array.length === 1) {
      return array[0].toString();
    } else {
      allButLastElement = array.slice(0, +(array.length - 2) + 1 || 9e9);
      return allButLastElement.join(', ') + ' and ' + array[array.length - 1];
    }
  };

  exports.getReadableTime = function(epochMilliseconds) {
    var date;
    date = new Date();
    //The time coming from the server here is actually epoc time, so we need to set it accordingly.
    date.setTime(epochMilliseconds);
    return date.toString();
  };

  exports.isOnline = function() {
    return window.navigator.onLine;
  };

  exports.assert = function(cond) {
    if (!cond) {
      throw new Error("assertion failed");
    }
  };

  exports.removeFromArray = function(array, toRemove) {
    var i;
    i = array.indexOf(toRemove);
    if (i < 0) {
      return false;
    }
    return array.splice(i, 1);
  };

  function getLoggerForType(type) {
    var _this = this;
    switch (type) {
      case 'w':  // warning
        return function() {
          var msg;
          msg = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          if (loggingEnabled)
            console.warn.apply(console, msg);
          else
            storeLog('warn', msg);
        };
      case 'e':  // error
        return function() {
          var msg;
          msg = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          console.error.apply(console, msg);
        };
      default:  // info
        return function() {
          var msg;
          msg = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          if (loggingEnabled)
            console.log.apply(console, msg);
          else
            storeLog('log', msg);
        };
    }
  }

  exports.getLogger = function(caller) {
    return function() {
      var msg, opt_type, type;
      opt_type = arguments[0], msg = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      if (opt_type === 'l' || opt_type === 'w' || opt_type === 'e') {
        type = opt_type;
      } else {
        msg = [opt_type].concat(msg);
      }
      return getLoggerForType(type).apply(null, ["" + caller.constructor.name + ":"].concat(__slice.call(msg)));
    };
  };

  var storedLogs = [];
  var MAX_NUM_STORED_LOGS = 400;
  function storeLog(type, msg) {
    storedLogs.push({type: type, msg: msg});
    if (storedLogs.length > MAX_NUM_STORED_LOGS) {
      storedLogs = storedLogs.slice(100);
    }
  };

  var loggingEnabled = false;
  exports.enableLogging = function() {
    loggingEnabled = true;
    // Display the last 300-400 logs.
    storedLogs.forEach(function(log) {
      console[log.type].apply(console, log.msg);
    });
    console.log('---------------------------------------------------');
    console.log('DEBUG: printed the last', storedLogs.length, 'logs.');
    console.log('---------------------------------------------------');
  };

  exports.pluralize = function(word, number) {
    if (!word || number === 1) {
      return word;
    }
    if (word[word.length - 1] === 's') {
      return word + 'es';
    } else {
      return word + 's';
    }
  };

  exports.truncateIfTooLarge = function(text, maxSize, suffix) {
    if (suffix == null) {
      suffix = '...';
    }
    if (text.length > maxSize) {
      return text.slice(0, +(maxSize - suffix.length - 1) + 1 || 9e9) + suffix;
    } else {
      return text;
    }
  };

  /*
   * Capitalizes the given string.
   * @param {string} sentence
   * @return {string}
  */
  exports.capitalizeString = function(sentence) {
    if (!sentence) {
      return sentence;
    }
    return sentence[0].toUpperCase() + sentence.slice(1);
  };

  /*
   * Returns whether or not the given string has non-whitespace characters.
   * @param {string} phrase
   * @return {boolean}
  */
  exports.stringHasContent = function(phrase) {
    if (!phrase) {
      return false;
    }
    return /\S/.test(phrase);
  };

  exports.html = {};

  exports.html.escape = function(html) {
    var escaped;
    escaped = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      '\'': '&apos;'
    };
    return String(html).replace(/[&<>"\']/g, function(character) {
      var _ref;
      return (_ref = escaped[character]) != null ? _ref : character;
    });
  };

  exports.html.stripColorCodes = function(html) {
    return html.replace(/\u0003\d{1,2}(,\d{1,2})?/g, '').replace(/[\x0F\x02\x1F\x1D]/g, '');
  };

  /*
   * Somewhat naive implementation of parsing color codes that does not respect
   * proper order of HTML open and close tags. Chrome doesn't seem to mind, though.
  */
  exports.html.parseColorCodes = function(html) {
    var colors = [
      "rgb(255, 255, 255)",
      "rgb(0, 0, 0)",
      "rgb(0, 0, 128)",
      "rgb(0, 128, 0)",
      "rgb(255, 0, 0)",
      "rgb(128, 0, 64)",
      "rgb(128, 0, 128)",
      "rgb(255, 128, 64)",
      "rgb(255, 255, 0)",
      "rgb(128, 255, 0)",
      "rgb(0, 128, 128)",
      "rgb(0, 255, 255)",
      "rgb(0, 0, 255)",
      "rgb(255, 0, 255)",
      "rgb(128, 128, 128)",
      "rgb(192, 192, 192)"
    ];

    var color = null,
        background = null,
        bold = false,
        italics = false,
        underline = false;

    var res = html.replace(/(\x0F|\x02|\x1F|\x1D|\u0003(\d{0,2})(?:,(\d{1,2}))?)([^\x0F\x02\x1F\x1D\u0003]*)/g, function(match, gr1, gr2, gr3, gr4) {
      if(gr1 == "\x0F") {
        color = null;
        background = null;
        bold = false;
        italics = false;
        underline = false;
      }else if(gr1 == "\x02") {
        bold = !bold;
      }else if(gr1 == "\x1F") {
        underline = !underline;
      }else if(gr1 == "\x1D") {
        italics = !italics;
      }else{
        if(gr2)
          color = colors[parseInt(gr2)];

        if(gr3)
          background = colors[parseInt(gr3)];
      }

      if(!gr4)
        return "";

      return "<font style='" +
              (color ? "color: " + color + ";" : "") +
              (background ? "background-color: " + background + ";" : "") +
              (bold ? "font-weight: bold;" : "") +
              (underline ? "text-decoration: underline;" : "") +
              (italics ? "font-style: italic;" : "") +
              "'>" +
              gr4 +
              "</font>";
    });

    return res;
  };

  /*
   * Escapes HTML and linkifies
  */
  exports.html.display = function(text, allowHtml) {
    var canonicalise, escape, m, res, rurl, textIndex;
    var escapeHTML = exports.html.escape;
    // Url-finding regex from Jan Goyvaerts.
    rurl = /\b(?:(?:https?|ftp|file):\/\/|www\.|ftp\.)(?:\([-A-Z0-9+&@#\/%=~_|$?!:,.]*\)|[-A-Z0-9+&@#\/%=~_|$?!:,.])*(?:\([-A-Z0-9+&@#\/%=~_|$?!:,.]*\)|[A-Z0-9+&@#\/%=~_|$])/gi;

    canonicalise = function(url) {
      url = exports.html.stripColorCodes(url);
      url = escapeHTML(url);
      if (url.match(/^[a-z][\w-]+:/i)) {
        return url;
      } else {
        return 'http://' + url;
      }
    };

    escape = function(str) {
      if (allowHtml)
        return str;
      // long words need to be extracted before escaping so escape HTML characters
      // don't scew the word length
      var longWords, replacement, result, word, _i, _len, _ref;
      longWords = (_ref = str.match(/\S{40,}/g)) != null ? _ref : [];
      longWords = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = longWords.length; _i < _len; _i++) {
          word = longWords[_i];
          _results.push(escapeHTML(word));
        }
        return _results;
      })();
      str = escapeHTML(str);
      result = '';
      for (_i = 0, _len = longWords.length; _i < _len; _i++) {
        word = longWords[_i];
        replacement = "<span class=\"longword\">" + word + "</span>";
        str = str.replace(word, replacement);
        result += str.slice(0, +(str.indexOf(replacement) + replacement.length - 1) + 1 || 9e9);
        str = str.slice(str.indexOf(replacement) + replacement.length);
      }
      return result + str;
    };

    res = '';
    textIndex = 0;
    while (m = rurl.exec(text)) {
      res += escape(text.substr(textIndex, m.index - textIndex));
      res += '<a target="_blank" href="' + canonicalise(m[0]) + '">' + escape(m[0]) + '</a>';
      textIndex = m.index + m[0].length;
    }
    res += escape(text.substr(textIndex));
    res = exports.html.parseColorCodes(res);

    return res;
  };

  /*
   * Opens a file browser and returns the contents of the selected file.
   * @param {function(string)} The function to call after the file content has be
   *     retrieved.
   */
  exports.loadFromFileSystem = function(callback) {
    var _this = this;
    return chrome.fileSystem.chooseFile({
      type: 'openFile'
    }, function(fileEntry) {
      if (!fileEntry) {
        return;
      }
      return fileEntry.file(function(file) {
        var fileReader;
        fileReader = new FileReader();
        fileReader.onload = function(e) {
          return callback(e.target.result);
        };
        fileReader.onerror = function(e) {
          return console.error('Read failed:', e);
        };
        return fileReader.readAsText(file);
      });
    });
  };

  exports.registerSocketConnection = function(socketId, remove) {
    if (window.chrome && chrome.runtime) {
      chrome.runtime.getBackgroundPage(function(page) {
        if (!page || !page.registerSocketId || !page.unregisterSocketId)
          return;
        if (remove)
          page.unregisterSocketId(socketId);
        else
          page.registerSocketId(socketId);
      });
    }
  };

  exports.registerTcpServer = function (socketId, remove) {
    if (window.chrome && chrome.runtime) {
      chrome.runtime.getBackgroundPage(function (page) {
        if (!page || !page.registerTcpServer || !page.unregisterTcpServer)
          return;
        if (remove)
          page.unregisterTcpServer(socketId);
        else
          page.registerTcpServer(socketId);
      });
    }
  };

}).call(this);
