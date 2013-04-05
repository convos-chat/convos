(function($) {
  var original_title = document.title;
  var current_title = original_title;
  var window_has_focus = true;
  var notifier, tid;

  window.notifier = {
    popup: function(title, msg, icon) {
      if(window_has_focus) return;
      if(notifier) notifier.createNotification(icon || '', title, msg || '').show();
      this.title(title);
      console.log([icon, title, msg]);
      tid = setInterval(this.title, 2000);
    },
    title: function(text) { // change title and make the tab flash (at least in chrome)
      if(window_has_focus) return;

      if(text) {
        current_title = text;
        clearInterval(tid);
      }

      if(document.title == current_title || document.title == original_title) {
        document.title = [original_title, current_title].join(' - ');
      }
      else {
        document.title = current_title;
      }
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
        clearInterval(tid);
        tid = setInterval(function() { document.title = original_title; clearInterval(tid); }, 4000);
        window_has_focus = true;
      });

      return this;
    }
  };
})(jQuery);
