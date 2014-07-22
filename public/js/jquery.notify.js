;(function($) {
  var original_title = document.title;
  var current_title = original_title;
  var has_focus = true;
  var focus_tid;

  $.notify = function(title, body, icon) {
    if (has_focus) return false;

    if (Notification.permission == 'granted') {
      var args = { icon: icon || '', body: body, onclose: function() { clearTimeout(tid); } };
      var n = new Notification(title, args);
      var tid = setTimeout(function() { n.close(); }, 5000);
      n.onclick = function(x) { window.focus(); this.cancel(); };
    }

    current_title = title;
    if (focus_tid) clearInterval(focus_tid);

    if (document.title == current_title || document.title == original_title) {
      document.title = [original_title, current_title].join(' - ');
    }
    else {
      document.title = current_title;
    }

    return true;
  };

  $(document).ready(function() {
    var $question = $('.notification.question');

    $question.each(function() {
      if (Notification.permission === 'granted') return false;
      if (Notification.permission === 'denied') return false;

      $question.find('a.yes').off('click').click(function() {
        if (Notification.permission === 'download') return true; // follow link

        Notification.requestPermission(function() {
          n = new Notification('Notifications enabled.', {});
          setTimeout(function() { n.close(); }, 2000);
        });
        $question.hide();
        return false;
      });

      $question.find('a.no').off('click').click(function() {
        $question.fadeOut('fast');
        Notification.permission = 'denied';
        return false;
      });

      $question.show();

      return false; // stop each() iterator
    });

    $(window)
      .on('blur', function() { has_focus = false; })
      .on('focus', function() {
        if (focus_tid) clearInterval(focus_tid);
        focus_tid = setInterval(function() { document.title = original_title; }, 3000);
        has_focus = true;
      });

  });
})(jQuery);

if (window.webkitNotifications) {
  window.Notification = function(title, args) {
    var n = window.webkitNotifications.createNotification(args.icon || '', title, args.body || '');

    try {
      if (args.onclose) n.onclose = args.onclose;
      if (args.onshow) n.ondisplay = args.onshow;
    } catch(e) {
      if (window.console) console.log('[Notification] ' + e);
    };

    n.close = function() { this.cancel(); if (this.onclose) this.onclose(); };
    n.show();
    return n;
  };
  window.Notification.permission = window.webkitNotifications.checkPermission() ? 'default' : 'granted';
  window.Notification.requestPermission = function(cb) {
    cb = cb || function() {};
    window.webkitNotifications.requestPermission(function() {
      window.Notification.permission = window.webkitNotifications.checkPermission() ? 'denied' : 'granted';
      cb(window.Notification.permission);
    });
  };
}
else if (!window.Notification) {
  window.Notification = function(title, args) {
    this.close = function() { if (this.onclose) this.onclose(); };
    this.show = function() {};
  };
  window.Notification.permission = navigator.userAgent.match(/firefox/i) ? 'download' : 'denied';
  window.Notification.requestPermission = function(cb) { cb('unsupported'); };
}
