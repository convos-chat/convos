;(function($) {
  $.fn.hideSidebar = function() {
    $('.sidebar-trigger-active').trigger('tap');
  };

  $(document).ready(function() {
    $('.sidebar-right').disableOuterScroll();

    $(window).on('tap', function(e) {
      var $e = $(e.target);
      if ($e.closest('.sidebar-trigger-active').length) return;
      if ($e.closest('.sidebar-right').length) return;
      $(this).hideSidebar();
    });

    $('a[href^="sidebar://"], button[value^="sidebar://"]').on('click', function(e) {
      e.preventDefault();
    }).on('tap', function(e) {
      var $a = $(this);
      var $t = $((this.href || this.value).replace(/^sidebar:\/\//, ''));
      var $hide;

      if ($a.hasClass('sidebar-trigger-active')) {
        if (e.originalEvent && e.originalEvent.type == 'focus') return false;
        $a.removeClass('active sidebar-trigger-active');
        $t.removeClass('active').css({ 'z-index': 1000 }).animate({ right: -($t.outerWidth() + 20) }, 100); // +20 to hide shadow
        if (!$('.sidebar-trigger-active').length && !navigator.is_touch_device) convos.input.focus();
        return false;
      }

      $hide = $('.sidebar-trigger-active').trigger('tap');
      if ($t.is(':animated')) return; // supposed to just hide, not show
      $a.addClass('active sidebar-trigger-active');
      $t.addClass('active').css({ 'z-index': 999, right: $hide.length ? 0 : -$t.outerWidth() }).show().animate({ right: 0 }, 150);
      $t.trigger('show');

      if (navigator.is_touch_device) {
        $t.find('select').each(function() { var s = this.selectize; if(s) setTimeout(function() { s.show(); }, 50); });
      }
      else {
        $t.find('a, button, input').eq(0).focus();
      }
    });
  });
})(jQuery);
