(function($) {
  var original_title = document.title;
  var current_title = original_title;
  var window_has_focus = true;
  var tid;

  if(!window.Notification) {
    if(window.webkitNotifications) {
      window.Notification = function(title, args) {
        var n = window.webkitNotifications.createNotification(args.iconUrl || '', title, args.body || '');
        $.each(['onshow', 'onclose'], function(k, i) { if(args[k]) this[k] = args[k]; });
        n.ondisplay = function() { if(this.onshow) this.onshow() };
        n.show();
        return n;
      };
      window.Notification.permission = 'default';
      window.Notification.requestPermission = function(cb) {
        webkitNotifications.requestPermission(function() {
          window.Notification.permission = webkitNotifications.checkPermission() ? 'denied' : 'granted';
          cb(window.Notification.permission);
        });
      };
      window.Notification.prototype.close = function() { if(this.onclose) this.onclose(); };
    }
    else {
      window.Notification = function(title, args) { return this; };
      window.Notification.permission = 'unsupported'; // TODO: "denied" instead?
      window.Notification.requestPermission = function(cb) { cb('unsupported'); };
      window.Notification.prototype.close = function() { if(this.onclose) this.onclose(); };
    }
  }

  window.notifier = {
    popup: function(title, msg, icon) {
      if(window_has_focus) return;
      new Notification(title, { iconUrl: icon, body: msg });
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
  };

  $(document).ready(function() {
    $(window).blur(function() {
      window_has_focus = false;
    });
    $(window).focus(function() {
      clearInterval(tid);
      tid = setInterval(function() { document.title = original_title; clearInterval(tid); }, 4000);
      window_has_focus = true;
    });
  });
})(jQuery);
