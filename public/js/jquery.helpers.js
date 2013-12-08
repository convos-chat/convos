;(function($) {
  var at_bottom_threshold = !!('ontouchstart' in window) ? 110 : 40;
  var original_title = document.title;
  var current_title = original_title;
  var has_fancy_scrollbars = /(iPad|iPhone|iPod)/g.test(navigator.userAgent);
  var $height_from, $win;

  var confirmFirst = function() {
    var $a = $(this);
    var confirm_text = 'Click again to confirm';
    var original_text = $a.text();
    if(original_text == confirm_text) return true;
    $a.text(confirm_text).one('mouseleave', function() { $a.text(original_text); });
    return false;
  };

  $.supportsTouch = 'ontouchstart' in window || navigator.msMaxTouchPoints;

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

  $.fn.focusSoon = function() {
    var $e = this.eq(0);
    setTimeout(function() { $e.focus(); }, 100);
    return this;
  };

  $.fn.initDropDown = function() {
    return this.each(function() {
      var $a = $(this);
      var $container = $( $a.data('toggle') );

      if(!has_fancy_scrollbars) {
        $container.addClass('nanoscroller').wrapInner('<div class="content"/>').nanoScroller({ preventPageScrolling: true });
      }

      $a.on('activate', function() {
        var $a = $(this);
        var height = $win.height() - 70;
        var left = $a.offset().left + $a.outerWidth() - $container.width();
        if(left < 10) left = 10;
        $container.css({ left: left, height: height }).nanoScroller();
      });
    });
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

  var hideToggledElement = function(e) {
    var $active = $('a[data-toggle]').filter('.active');
    if(!$active.length) return true;
    if($(e.target).closest($active).length) return true; // prevent hiding when clicking inside forms
    $active.trigger('deactivate');
    return false;
  };

  $.fn.toggleElementWithClick = function() {
    return this.each(function() {
      var $a = $(this);
      var focus = $a.attr('data-focus');
      var target = $a.attr('data-toggle');
      var inside = false;

      $(target).on('click', 'a', function() { $a.trigger('deactivate'); });
      $a.on('deactivate', function() { $a.removeClass('active'); $(target).hide(); });
      $a.on('activate', function() { $a.removeClass('active'); $a.click(); });
      $a.click(function(e) {
        if(inside) return false;
        var $target = $(target);
        var is_active = $a.hasClass('active');

        $(document).off('click', hideToggledElement);
        $('a[data-toggle]').filter('.active').trigger('deactivate');
        if(is_active) return false;

        if(!$a.hasClass('active')) {
          inside = true;
          $target.show();
          $a.data('target', $target).trigger('activate').addClass('active');
          inside = false;
          if(focus) $(focus, target).eq(0).focusSoon();
          if(!$target.hasClass('ignore-document-close')) $(document).one('click', hideToggledElement);
        }

        return false;
      });
    })
  };

  $.url_for = function() {
    var args = $.makeArray(arguments);
    args.unshift($('html').data('basepath').replace(/\/$/, ''));
    return args.join('/').replace(/#/g, '%23');
  };

  $(document).ready(function() {
    var $togglers = $('a[data-toggle]').toggleElementWithClick();
    var $focus = $togglers.filter('.active').trigger('activate').filter('.focus');
    var $login_button = $('a[data-toggle="div.login"]');

    $('a.confirm').click(confirmFirst);

    if($login_button.length) {
      $('body').bind('keydown', 'shift+return', function(e) {
        e.preventDefault();
        $login_button.click();
      });
    }
    if(has_fancy_scrollbars) {
      $.fn.nanoScroller = function() { return this; };
    }

    $height_from = $('div.wrapper').length ? $('div.wrapper') : $('body');
    $win = $(window).data('at_bottom', false).data('has_focus', true);
    $(document).data('height_from', $height_from);

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
  });

})(jQuery);
