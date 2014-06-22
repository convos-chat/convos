;(function($) {
  var initNotifications = function() {
    if(Notification.permission === 'granted') return;
    if(Notification.permission === 'unsupported') return;
    if(Notification.permission === 'denied') return;

    var $ask_for_notifications = $('div.notification.question');

    $ask_for_notifications.find('a.yes').off('click').click(function() {
      Notification.requestPermission(function() {
        n = new Notification('Notifications enabled.', {});
        setTimeout(function() { n.close(); }, 2000);
      });
      $ask_for_notifications.hide();
      return false;
    });
    $ask_for_notifications.find('a.no').off('click').click(function() {
      $ask_for_notifications.fadeOut('fast');
      Notification.permission = 'denied';
      return false;
    });
    $ask_for_notifications.show();
  };

  $(document).ready(function() {
    if($('.notification.question').length) initNotifications();
  });
})(jQuery);

/*
 * Author: Jan Henning Thorsen - jhthorsen@cpan.org
 *
 * This will enable a HTML5 notification compatible API in chrome and other
 * HTML5 ready browsers.
 * See http://www.w3.org/TR/notifications/ for documentation.
 *
 * Notes
 * - The requestPermission() callback may receive "unsupported" (non-standard)
 * - It prefers window.webkitNotifications if available
 * - You can enable notifications in firefox with
 *   https://addons.mozilla.org/en-us/firefox/addon/html-notifications/
 */
if(window.webkitNotifications) {
  window.Notification = function(title, args) {
    var n = window.webkitNotifications.createNotification(args.iconUrl || '', title, args.body || '');

    try {
      if(args.onclose) n.onclose = args.onclose;
      if(args.onshow) n.ondisplay = args.onshow;
    } catch(e) {
      if(window.console) console.log('[Notification] ' + e);
    };

    n.show();
    return n;
  };
  window.Notification.permission = window.webkitNotifications.checkPermission() ? 'denied' : 'granted';
  window.Notification.requestPermission = function(cb) {
    cb = cb || function() {};
    window.webkitNotifications.requestPermission(function() {
      window.Notification.permission = window.webkitNotifications.checkPermission() ? 'denied' : 'granted';
      cb(window.Notification.permission);
    });
  };
  window.Notification.prototype.close = function() { if(this.onclose) this.onclose(); };
}
else if(!window.Notification) {
  window.Notification = function(title, args) { return this; };
  window.Notification.permission = 'unsupported'; // TODO: "denied" instead?
  window.Notification.requestPermission = function(cb) { cb('unsupported'); };
  window.Notification.prototype.close = function() { if(this.onclose) this.onclose(); };
}
