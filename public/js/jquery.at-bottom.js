;(function($) {
  var at_bottom_threshold = !!('ontouchstart' in window) ? 110 : 40;
  var $win = $(window);

  $.fn.scrollTo = function(pos) {
    if(pos === 'bottom') {
      $(this).scrollTop($('body').height());
    }
    else {
      $(this).scrollTop(pos);
    }
    return this;
  };

  $.fn.atBottom = function() {
    return $win.scrollTop() + $win.height() > $('body').height() - at_bottom_threshold;
  };
})(jQuery);
