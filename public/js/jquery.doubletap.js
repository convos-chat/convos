(function($){
  var ios = /(iPad|iPhone|iPod)/g.test(navigator.userAgent);

  $.fn.doubletap = function(cb) {
    return this.each(function() {
      var last = new Date().getTime();

      $(this).bind('touchend', function(e) {
        var now = new Date().getTime();
        var delta = now - last;

        if(delta < 500 && delta > 0) {
          e.preventDefault();
          e.stopPropagation();
          last = 0;
          cb(e);
        }
        else {
          last = now;
        }
      });
    });
  };
})(jQuery);
