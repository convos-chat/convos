(function(window) {
  var s4 = function() {
    return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
  };

  window.guid = function() {
    return [ s4() + s4(), s4(), s4(), s4(), s4() + s4() + s4() ].join('-');
  };
})(window);

// super cheap sorted set implementation
window.sortedSet = function() { this.set = { length: 0 }; return this; };
window.sortedSet.prototype.add = function(score, member) { this.set[member] = score; this.length++; return this; };
window.sortedSet.prototype.clear = function() { this.set = {}; this.length = 0; return this; };
window.sortedSet.prototype.rem = function(member) { delete this.set[member]; this.length--; return this; };
window.sortedSet.prototype.score = function(member) { return this.set[member] };
window.sortedSet.prototype.revrange = function(start, stop) {
  var k, res = [], self = this;
  for(k in self.set) res.push(k);
  if(start < 0) start = res.length + start;
  if(stop < 0) stop = res.length + stop + 1;
  return res.sort(function(a, b) { return self.set[b] - self.set[a]; }).splice(start, stop);
};

// console.log()
window.console = window.console || { log: function() { window.console.messages.push(arguments) }, messages: [] };
window.console._debug = function() { if(window.DEBUG) window.console.log.apply(window.console, arguments) };

// add escape() with the *same* functionality as per's quotemeta()
RegExp.escape = RegExp.escape || function(str) {
  return str.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g, "\\$&");
};

Array.prototype.unique = function() {
  var r = [];
  for(i = 0; i < this.length; i++) {
    if(r.indexOf(this[i]) === -1) r.push(this[i]);
  }
  return r;
};

Array.prototype.sortCaseInsensitive = function() {
  return this.sort(function(a, b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    return a == b ? 0 : a > b ? 1 : -1;
  });
};

Object.equals = function(a, b) {
  for(p in a) {
    switch(typeof(a[p])) {
      case 'object':
        if(!a[p].equals(b[p])) return false;
        break;
      case 'function':
        if(typeof(b[p])=='undefined' || (p != 'equals' && a[p].toString() != b[p].toString())) return false;
        break;
      default:
        if(a[p] != b[p]) return false;
    }
  }

  for(p in b) {
    if(typeof(a[p])=='undefined') return false;
  }

  return true;
};

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

