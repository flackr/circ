exports = window.chat ?= {}

##
# Indicates that a dom element can be scrolled and provides scroll utility
# functions.
##
class Scrollable

  ##
  # The screen will auto scroll as long as the user didn't scroll up more then
  # this many pixels.
  ##
  @SCROLLED_DOWN_BUFFER = 8

  ##
  # @param {Node} element The jquery DOM element to wrap.
  ##
  constructor: (node) ->
    @_node = node
    node.restoreScrollPosition = @_restoreScrollPosition
    @_scrollPosition = 0
    @_wasScrolledDown = true
    $(window).resize @_restoreScrollPosition
    $(node).scroll @_onScroll
    return node

  ##
  # Restore the scroll position to where the user last scrolled. If the node
  # was scrolled to the bottom it will remain scrolled to the bottom.
  #
  # This is useful for restoring the scroll position after adding content or
  # resizing the window.
  ##
  _restoreScrollPosition: =>
    if @_wasScrolledDown
      @_scrollToBottom()
    else
      @_node.scrollTop @_scrollPosition

  _scrollToBottom: ->
    @_node.scrollTop @_getScrollHeight()

  _onScroll: =>
    @_wasScrolledDown = @_isScrolledDown()
    @_scrollPosition = @_node.scrollTop()

  _isScrolledDown: ->
    scrollPosition = @_node.scrollTop() + @_node.height()
    scrollPosition >= @_getScrollHeight() - Scrollable.SCROLLED_DOWN_BUFFER

  _getScrollHeight: ->
    @_node[0].scrollHeight

exports.Scrollable = Scrollable