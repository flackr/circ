(function() {
  "use strict";

  describe('A nick list', function() {
    var win = {};
    var item = function(index) {
      if (index === -1) {
        return items().last();
      }
      return $(items()[index]);
    };
    var items = function() {
      return $('#nicks-container .nicks .nick');
    };
    beforeEach(function() {
      mocks.dom.setUp();
      win = new chat.Window('name');
      win.attach();
      return spyOn(win.nicks, 'emit');
    });
    afterEach(function() {
      win.detach();
      return mocks.dom.tearDown();
    });
    return it("emits a dblclicked event when a nick is double-clicked", function() {
      win.nicks.add('foo');
      item(0).trigger(new MouseEvent('dblclick'));
      return expect(win.nicks.emit).toHaveBeenCalledWith('dblclicked', 'foo');
    });
  });

}).call(this);
