// Generated by CoffeeScript 1.4.0

/*
 * This class provides convenience functions for scripts which make talking to
 * the IRC client easier.
 *#
*/


(function() {
//  "use strict";
  var _this = this,
    __slice = [].slice;

  addEventListener('message', function(e) {
    if (typeof _this.onMessage === 'function') {
      return _this.onMessage(e.data);
    }
  });

  /*
   * Set the name of the script. This is the name displayed in /scripts and used with /uninstall.
   * @param {string} name
  */


  this.setName = function(name) {
    return _this.send('meta', 'name', name);
  };

  this.setDescription = function(description) {
    /*
       * TODO
    */

  };

  /*
   * Retrieve the script's saved information, if any, from sync storage.
  */


  this.loadFromStorage = function() {
    return _this.send({}, 'storage', 'load');
  };

  /*
   * Save the script's information to sync storage.
   * @param {Object} item The item to save to storage.
  */


  this.saveToStorage = function(item) {
    return _this.send({}, 'storage', 'save', item);
  };

  /*
   * Send a message to the IRC server or client.
   * @param {{server: string, channel: string}=} Specifies which room the event
   *     takes place in. Events like registering to handle a command don't need
   *     a context.
   * @param {string} type The type of event (e.g. command, message, etc)
   * @param {string} name The sub-type of the event (e.g. the type of command or
   *##
   *     message)
   * @param {Object...} args A variable number of arguments for the event.
   *##
  */


  this.send = function() {
    var args, context, event, name, opt_context, type;
    opt_context = arguments[0], type = arguments[1], name = arguments[2], args = 4 <= arguments.length ? __slice.call(arguments, 3) : [];
    if (typeof opt_context === 'string') {
      args = [name].concat(args);
      name = type;
      type = opt_context;
      context = {};
    } else {
      context = opt_context;
    }
    event = {
      context: context,
      type: type,
      name: name,
      args: args
    };
    return _this.sendEvent(event);
  };

  this.sendEvent = function(event) {
    return window.parent.postMessage(event, '*');
  };

  this.propagate = function(event, propagation) {
    if (propagation == null) {
      propagation = 'all';
    }
    return _this.send(event.context, 'propagate', propagation, event.id);
  };

}).call(this);
