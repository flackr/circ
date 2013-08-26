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
    var textOfItem = function(index) {
      return $('.content-item', item(index)).text();
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
    it("sorts entries properly", function() {
      win.nicks.add('_psi');
      win.nicks.add('epsilon');
      win.nicks.add('Delta');
      win.nicks.add('gamma');
      win.nicks.add('Beta');
      win.nicks.add('alpha');
      expect(textOfItem(0)).toBe('_psi');
      expect(textOfItem(1)).toBe('alpha');
      expect(textOfItem(2)).toBe('Beta');
      expect(textOfItem(3)).toBe('Delta');
      expect(textOfItem(4)).toBe('epsilon');
      expect(textOfItem(5)).toBe('gamma');
    });
    return it("emits a dblclicked event when a nick is double-clicked", function() {
      win.nicks.add('foo');
      item(0).trigger(new MouseEvent('dblclick'));
      return expect(win.nicks.emit).toHaveBeenCalledWith('dblclicked', 'foo');
    });
  });

}).call(this);
