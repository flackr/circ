// Generated by CoffeeScript 1.4.0
(function() {
  "use strict";
  var Scrollable, exports, _ref,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  exports = (_ref = window.chat) != null ? _ref : window.chat = {};

  /*
   * Indicates that a dom element can be scrolled and provides scroll utility
   * functions.
  */


  Scrollable = (function() {
    /*
       * The screen will auto scroll as long as the user didn't scroll up more then
       * this many pixels.
    */

    Scrollable.SCROLLED_DOWN_BUFFER = 8;

    /*
       * @param {Node} element The jquery DOM element to wrap.
    */


    function Scrollable(node) {
      this._onScroll = __bind(this._onScroll, this);

      this._restoreScrollPosition = __bind(this._restoreScrollPosition, this);
      this._node = node;
      node.restoreScrollPosition = this._restoreScrollPosition;
      this._scrollPosition = 0;
      this._wasScrolledDown = true;
      $(window).resize(this._restoreScrollPosition);
      $(node).scroll(this._onScroll);
    }

    Scrollable.prototype.node = function() {
      return this._node;
    };

    /*
       * Restore the scroll position to where the user last scrolled. If the node
       * was scrolled to the bottom it will remain scrolled to the bottom.
       *
       * This is useful for restoring the scroll position after adding content or
       * resizing the window.
    */


    Scrollable.prototype._restoreScrollPosition = function() {
      if (this._wasScrolledDown) {
        return this._scrollToBottom();
      } else {
        return this._node.scrollTop(this._scrollPosition);
      }
    };

    Scrollable.prototype._scrollToBottom = function() {
      return this._node.scrollTop(this._getScrollHeight());
    };

    Scrollable.prototype._onScroll = function() {
      this._wasScrolledDown = this._isScrolledDown();
      return this._scrollPosition = this._node.scrollTop();
    };

    Scrollable.prototype._isScrolledDown = function() {
      var scrollPosition;
      scrollPosition = this._node.scrollTop() + this._node.height();
      return scrollPosition >= this._getScrollHeight() - Scrollable.SCROLLED_DOWN_BUFFER;
    };

    Scrollable.prototype._getScrollHeight = function() {
      return this._node[0].scrollHeight;
    };

    return Scrollable;

  })();

  exports.Scrollable = Scrollable;

}).call(this);
