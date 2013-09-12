// modified version by jhthorsen@cpan.org
// http://x1024.github.io/jquery-fastbutton/
// https://raw.github.com/x1024/jquery-fastbutton/master/bin/fastbutton.js
(function() {
  var Clickbuster, clickDistance, clickbusterDistance, clickbusterTimeout, eventHandler;
  clickbusterDistance = 20;
  clickbusterTimeout = 2500;
  clickDistance = 5;

  Clickbuster = (function() {
    function Clickbuster() {}
    Clickbuster.coordinates = [];

    Clickbuster.preventGhostClick = function(x, y) {
      Clickbuster.coordinates.push(x, y);
      return window.setTimeout(Clickbuster.pop, clickbusterTimeout);
    };

    Clickbuster.pop = function() {
      return Clickbuster.coordinates.splice(0, 2);
    };

    Clickbuster.onClick = function(e) {
      var coordinates, dx, dy, i, x, y;
      coordinates = Clickbuster.coordinates;
      i = 0;
      if (e.clientX == null) return true;
      window.ev = e;
      while (i < coordinates.length) {
        x = coordinates[i];
        y = coordinates[i + 1];
        dx = Math.abs(e.clientX - x);
        dy = Math.abs(e.clientY - y);
        i += 2;
        if (dx < clickbusterDistance && dy < clickbusterDistance) return false;
      }
      return true;
    };

    return Clickbuster;
  })();

  eventHandler = function(handleObj) {
    var origHandler;
    origHandler = handleObj.handler;
    return handleObj.handler = function(e) {
      if (!Clickbuster.onClick(e)) return false;
      return origHandler.apply(this, arguments);
    };
  };

  $.event.special.click = { add: eventHandler };
  $.event.special.submit = { add: eventHandler };

  $.fn.fastButton = function(selector) {
    selector = selector || 'a';
    return this.each(function() {
      var self = this, handlers;
      if (!('ontouchstart' in window)) return;
      self.active = false;
      handlers = {
        touchstart: function(e) {
          var touch = e.originalEvent.touches[0];
          self.active = true;
          self.startX = touch.clientX;
          self.startY = touch.clientY;
        },
        touchend: function(e) {
          if (!self.active) return;
          e.preventDefault();
          self.active = false;
          Clickbuster.preventGhostClick(self.startX, self.startY);
          return $(this).trigger('click');
        }
      };
      $(self).on(handlers, selector).on('touchmove', function(e) {
        var dx, dy, touch;
        if (!self.active) return;
        touch = e.originalEvent.touches[0];
        dx = Math.abs(touch.clientX - self.startX);
        dy = Math.abs(touch.clientY - self.startY);
        if (dx > clickDistance || dy > clickDistance) self.active = false;
      });
    });
  }; // end fastButton()
}).call(this);
