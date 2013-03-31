(function($) {
  var original_title = document.title;
  var current_title = original_title;
  var window_has_focus = true;
  var notifier, tid;

  window.notifier = {
    popup: function(title, msg, icon) {
      if(window_has_focus) return;
      if(notifier) notifier.createNotification(icon || '', title, msg || '').show();
    },
    title: function(text) { // change title and make the tab flash (at least in chrome)
      if(tid) clearTimeout(tid);
      if(window_has_focus) return;
      if(text) current_title = text;

      if(document.title == current_title || document.title == original_title) {
        document.title = current_title + ' - ' + original_title;
      }
      else {
        document.title = current_title;
      }

      tid = setTimeout(this.title, 2000);
    },
    requestPermission: function() {
      webkitNotifications.requestPermission(function() {
        if(!webkitNotifications.checkPermission()) notifier = window.notifier;
      });
    },
    init: function() {
      if(!window.webkitNotifications) {
        // cannot show notifications
      }
      else if(webkitNotifications.checkPermission()) {
        // cannot run requestPermission() without a user action, such as mouse click or key down
        $(document).one('keydown', function() { window.notifier.requestPermission(); });
      }
      else {
        notifier = webkitNotifications;
      }

      $(window).blur(function() {
        window_has_focus = false;
      });
      $(window).focus(function() {
        window_has_focus = true;
        tid = setTimeout(function() { document.title = original_title; }, 4000);
      });

      return this;
    }
  };
})(jQuery);
