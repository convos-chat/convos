(function($) {
  $.fn.disableOuterScroll = function() {
    return this.on('mousewheel DOMMouseScroll', function(e) {
      var scrollTo = e.type == 'mousewheel'     ? e.originalEvent.wheelDelta * -1
                   : e.type == 'DOMMouseScroll' ? 40 * e.originalEvent.detail
                   : false;

      if (!scrollTo) return
      e.preventDefault();
      $(this).scrollTop(scrollTo + $(this).scrollTop());
    });
  };
})(jQuery);
