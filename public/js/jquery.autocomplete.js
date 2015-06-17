;(function($) {
  $.fn.autocomplete = function(opts) {
    var $input = this;
    var $wrapper = $input.siblings('.autocomplete').disableOuterScroll();
    var n = 0;

    $wrapper.find('li:visible').not('.no-match').eq(0).addClass('active');
    $wrapper.find('li.no-match')[$wrapper.find('li:visible').length ? 'hide' : 'show']();
    if (opts == 'update') return;

    $wrapper.on('click', 'li > a', function(e) {
      e.preventDefault()
      $input.val($(this).attr('href')).focus();
      n = $(this).closest('li').index();
      $wrapper.find('li:visible').removeClass('active').eq(n).addClass('active');
    });

    $input.on('keydown', function(e) {
      switch (e.keyCode) {
        case 38: // up
        case 40: // down
          e.preventDefault();
      }
    });

    $input.on('keyup', function(e) {
      var $li = $wrapper.height($wrapper.height()).find('li').not('.no-match');
      var re = new RegExp(this.value, 'i');

      switch (e.keyCode) {
        case 13: // enter
          this.value = $li.filter('.active').eq(0).find('a').attr('href');
          break;
        case 38: // up
          $li = $li.filter(':visible').removeClass('active');
          if (--n < 0) n = $li.length - 1;
          break;
        case 40: // down
          $li = $li.filter(':visible').removeClass('active');
          if (++n >= $li.length) n = 0;
          break;
        case 37: // left
          break;
        case 39: // right
          break;
        default:
          n = 0;
          $li = $li.each(function() {
            var $a = $(this);
            if ($a.text().match(re)) return $a.show().removeClass('active');
            $a.hide();
          }).filter(':visible');
      }

      if ($li.length) {
        $wrapper.find('li.no-match').hide();
        $wrapper.scrollTo($li.eq(n).addClass('active'));
      }
      else {
        $wrapper.find('li.no-match').show();
      }
    });

    return this;
  };
}(jQuery));
