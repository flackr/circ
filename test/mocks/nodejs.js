// Make included NodeJS export to window object.
window.exports = window;

var packages = {
  'google-auth-library': {prototype: {}},
};

var exports = {
};

window.__dirname = 'server/';

window.require = function(package) {
  return packages[package];
};

function NodeJSEventSource() {
}

NodeJSEventSource.prototype = {
  once: function(type, fn) {
    this.on_ = this.on_ || {};
    this.on_[type] = function() {
      delete this.on_[type];
      fn.apply(null, Array.prototype.slice.call(arguments, 0));
    }.bind(this);
  },
  on: function(type, fn) {
    this.on_ = this.on_ || {};
    this.on_[type] = fn;
  },
  dispatch: function(type) {
    if (this.on_[type])
      this.on_[type].apply(/* this */ null, /* args */ Array.prototype.slice.call(arguments, 1));
    else
      console.log('Warning, no handler for event type ' + type);
  }
}

