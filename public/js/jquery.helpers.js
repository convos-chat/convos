navigator.is_ios = /(iPad|iPhone|iPod)/g.test(navigator.userAgent);

;(function($) {
  var at_bottom_threshold = !!('ontouchstart' in window) ? 110 : 40;
  var original_title = document.title;
  var current_title = original_title;
  var has_fancy_scrollbars = /(iPad|iPhone|iPod)/g.test(navigator.userAgent);
  var $height_from, $win;

  $.notify = function(title, body, icon) {
    if($win.data('has_focus')) return this;

    if(Notification.permission == 'granted') {
      var n = new Notification(
                title,
                {
                  iconUrl: icon,
                  body: body,
                  onclose: function() { clearTimeout(tid); }
                }
              );
      n.onclick = function(x) { window.focus(); this.cancel(); };
      var tid = setTimeout(function() { n.close(); }, 5000);
    }

    current_title = title;
    if($.notify.focus_tid) clearInterval($.notify.focus_tid);

    if(document.title == current_title || document.title == original_title) {
      document.title = [original_title, current_title].join(' - ');
    }
    else {
      document.title = current_title;
    }

    return this;
  };

  $.fn.loadingIndicator = function(action) {
    if(action == 'hide') {
      this.find('.loading-indicator-overlay, .loading-indicator').remove();
    }
    else {
      var position = this.css('position') || 'static';
      if(position == 'static') this.css('position', 'relative');
      this.append('<div class="loading-indicator-overlay"></div><div class="loading-indicator"></div>');
    }
    return this;
  };

  $.fn.scrollTo = function(pos) {
    if(pos === 'bottom') {
      $(this).scrollTop($height_from.height());
      $win.data('at_bottom', true);
    }
    else {
      $(this).scrollTop(pos);
      $win.data('at_bottom', false);
    }
    return this;
  };

  $.fn.toggler = function() {
    return this.on('click focus', function(e) {
      var $a = $(this);
      var $t = $(this.href.replace(/^toggle:\/\//, ''));
      var $hide;

      e.preventDefault();

      if($a.hasClass('active')) {
        if(e.originalEvent && e.originalEvent.type == 'focus') return false;
        $a.removeClass('active');
        $t.removeClass('active').css({ 'z-index': 900 }).animate({ right: -($t.outerWidth() + 20) }, 100); // +20 to hide shadow
        if(!$('a.toggler.active').length && !navigator.is_ios) $('.input input').focus();
        return false;
      }

      $hide = $('a.toggler.active');
      $hide.click();
      $a.addClass('active');
      $t.addClass('active').css({ 'z-index': 901, right: $hide.length ? 0 : -$t.outerWidth() }).show().animate({ right: 0 }, 150);
      $t.find('a, button, input').eq(0).focus();
      return false;
    });
  };

  $.url_for = function() {
    var args = $.makeArray(arguments);
    args[0] = args[0].replace(/^\//, '');
    args.unshift($('html').data('basepath').replace(/\/$/, ''));
    return args.join('/').replace(/#/g, '%23');
  };

  $(document).ready(function() {
    $height_from = $('div.wrapper').length ? $('div.wrapper') : $('body');
    $win = $(window).data('at_bottom', false).data('has_focus', true);
    $(document).data('height_from', $height_from);

    $('body').on('click', function(e) {
      if ($(e.target).closest('.sidebar-right').length) return;
      $('a.toggler.active').click();
    });

    $win.on('scroll', function() {
      var at_bottom = $win.scrollTop() + $win.height() > $height_from.height() - at_bottom_threshold;
      $win.data('at_bottom', at_bottom);
    });
    $win.blur(function() {
      $win.data('has_focus', false);
    });
    $win.focus(function() {
      if($.notify.focus_tid) clearInterval($.notify.focus_tid);
      $.notify.focus_tid = setInterval(function() { document.title = original_title; }, 3000);
      $win.data('has_focus', true);
    });

    $('a[href^="toggle://"]').toggler();
  });
})(jQuery);
