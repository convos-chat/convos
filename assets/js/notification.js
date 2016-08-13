(function() {
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
    window.Notification.permission = navigator.userAgent.match(/firefox/i) ? 'download' : 'denied'; // must be denied for iOS
    window.Notification.requestPermission = function(cb) { cb('denied'); };
  }

  window.Notification.defaultCloseTimeout = 5000;
  window.Notification.simple = function(title, body, icon) {
    if (window.hasFocus) return false;

    if (Notification.permission == 'granted') {
      var args = { icon: icon || '', body: body, onclose: function() { clearTimeout(tid); } };
      var n = new Notification(title, args);
      var tid = setTimeout(function() { n.close(); }, Notification.defaultCloseTimeout);
      n.onclick = function(x) { this.cancel(); window.focus(); };
    }

    // TODO: Change favicon or make the icon bare blink by changing document.title

    return true;
  };
})();
