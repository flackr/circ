var utf8 = '✓';
(function() {
  "use strict";

  describe("IRC Utils provides the following functions:", function() {

    var waitsForArrayBufferConversion;
    waitsForArrayBufferConversion = function() {
      return waitsFor((function() {
        return !window.irc.util.isConvertingArrayBuffers();
      }), 'wait for array buffer conversion', 500);
    };

    describe("fromSocketData", function() {
      var fromSocketData = irc.util.fromSocketData;
      var ab, cb;
      beforeEach(function() {
        cb = jasmine.createSpy('cb');
      });

      it("calls the callback", function() {
        ab = irc.util.arrayToArrayBuffer([65]);
        fromSocketData(ab, cb);
        waitsForArrayBufferConversion();
        return runs(function() {
          expect(cb).toHaveBeenCalledWith('A');
        });
      });

      describe("handles encoding", function() {

        [
          'ISO 8859-1'
        ].forEach(function(encoding) {
          it(encoding, function() {
            ab = irc.util.arrayToArrayBuffer([116, 115, 99, 104, 246]);
            fromSocketData(ab, cb);
            waitsForArrayBufferConversion();
            return runs(function() {
              expect(cb).toHaveBeenCalledWith('tschö✓');
            });
          });
        });
      });
    });
  });
})();
