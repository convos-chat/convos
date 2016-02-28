;(function(window) {
window.isApple = navigator.userAgent.match(/iPhone/i) || navigator.userAgent.match(/iPod/i);
window.isTouchDevice = !!('ontouchstart' in window);
window.isWideScreen = window.innerWidth > window.wideScreenWidth;
window.wideScreenWidth = 820;
window.DEBUG = window.DEBUG || true;

window.nextTick = function(cb) { setTimeout(cb, 1); };
window.TODO = function(message) { alert("TODO: " + message); };

window.addEventListener('resize', function(e) {
  if (window.innerWidth > window.wideScreenWidth == window.isWideScreen) return;
  window.isWideScreen = !window.isWideScreen;
  riot.update();
});

String.prototype.parseUrl = function() {
  var m = this.match(new RegExp("^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?"));
  if (!m) return {};
  var s = {scheme: m[2], authority: m[4], path: m[5], fragment: m[9], query: {}};
  var p = m[4].split('@', 2);
  s.hostPort = p[1] || p[0];
  s.userinfo = p.length == 2 ? p[0].split(':', 2) : [];
  p = m[7] ? m[7].split('&') : [];
  p.forEach(function(i) { var kv = i.split('=', 2); s.query[kv[0]] = kv[1]; });
  return s;
};

String.prototype.ucFirst = function() {
  return this.replace(/^./, function(m) { return m.toUpperCase(); });
};

var xml = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  '\'': '&#39;'
};
String.prototype.xmlEscape = function() {
  return this.replace(/[&<>"']/g, function(m) { return xml[m]; });
};

Date.prototype.epoch = function() {
  return this.getTime() / 1000;
};

Date.prototype.getAbbrMonth = function() {
  switch(this.getMonth()) {
    case 0: return 'Jan';
    case 1: return 'Feb';
    case 2: return 'March';
    case 3: return 'Apr';
    case 4: return 'May';
    case 5: return 'Jun';
    case 6: return 'July';
    case 7: return 'Aug';
    case 8: return 'Sept';
    case 9: return 'Oct';
    case 10: return 'Nov';
    case 11: return 'Dec';
  }
};

Date.prototype.getHM = function() {
  return [this.getHours(), this.getMinutes()].map(function(v) { return v < 10 ? '0' + v : v; }).join(':');
};
})(window);
