;(function($) {
  $(document).ready(function() {
    $('body').on('click', function(e) {
      if ($(e.target).closest('.sidebar-right').length) return;
      $('a.btn-sidebar.active').click();
    });

    $('a[href^="sidebar://"]').on('click focus', function(e) {
      var $a = $(this);
      var $t = $(this.href.replace(/^sidebar:\/\//, ''));
      var $hide;

      e.preventDefault();

      if ($a.hasClass('active')) {
        if (e.originalEvent && e.originalEvent.type == 'focus') return false;
        $a.removeClass('active');
        $t.removeClass('active').css({ 'z-index': 900 }).animate({ right: -($t.outerWidth() + 20) }, 100); // +20 to hide shadow
        if (!$('a.btn-sidebar.active').length && !navigator.is_ios) $('.input input').focus();
        return false;
      }

      $hide = $('a.btn-sidebar.active');
      $hide.click();
      $a.addClass('active');
      $t.addClass('active').css({ 'z-index': 901, right: $hide.length ? 0 : -$t.outerWidth() }).show().animate({ right: 0 }, 150);
      $t.find('a, button, input').eq(0).focus();
      return false;
    });
  });
})(jQuery);
