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

      describe("handles encoding", function() {
        [
          ['UTF-8', [0x61, 0xE2, 0x9C, 0x93], 'a✓'],
          ['ISO 8859-1', [0x74, 0x73, 0x63, 0x68, 0xFC, 0xDF], 'tschüß']
        ].forEach(function(parts) {
          var encoding = parts[0],
              array = parts[1],
              text = parts[2];
          it(encoding, function() {
            ab = irc.util.arrayToArrayBuffer(array);
            fromSocketData(ab, cb);
            waitsForArrayBufferConversion();
            return runs(function() {
              expect(cb).toHaveBeenCalledWith(text);
            });
          });
        });
      });
    });
  });
})();
