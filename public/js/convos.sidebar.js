;(function($) {
  var showing = false;
  var $togglers = $();
  var $main = $();

  $.fn.hideSidebar = function() {
   $togglers.filter('.active').trigger('tap');
  };

  $(document).ready(function() {
    $main = $('a[href^="sidebar://form.sidebar"]')
    $togglers = $('a[href^="sidebar://"], button[value^="sidebar://"]');

    $('.sidebar-right').disableOuterScroll();

    $(window).on('tap', function(e) {
      var $e = $(e.target);
      if ($e.closest('.active').length) return;
      if ($e.closest('.sidebar-right').length) return;
      $(this).hideSidebar();
    });

    $togglers.on('click', function(e) { e.preventDefault(); });
    $togglers.on('tap', function(e) {
      var $a = $(this);
      var $t = $((this.href || this.value).replace(/^sidebar:\/\//, ''));

      if ($a.hasClass('active')) {
        $a.removeClass('active');
        if (!showing) $togglers.filter('.keep-open').addClass('active');
        if (!$a.hasClass('keep-open')) $t.removeClass('active');
        if (!$togglers.filter('.active').length && !navigator.is_touch_device) convos.input.focus();
        return false;
      }

      showing = true;
      $togglers.filter('.active').trigger('tap');
      $t.addClass('active').trigger('show');
      $a.addClass('active');
      showing = false;

      if (!navigator.is_touch_device) {
        $t.find('a, button, input').eq(0).focus();
      }
    });

    $(window).resize();
  });

  $(window).on('resize', function() {
    if ($(document).width() < convos.responsiveWidth) {
      if ($main.hasClass('keep-open')) $main.removeClass('keep-open').trigger('tap');
    }
    else {
      if (!$main.hasClass('keep-open')) $main.addClass('keep-open').trigger('tap');
    }
  });
})(jQuery);
