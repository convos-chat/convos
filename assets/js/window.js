;(function(window) {
var atBottomThreshold = !!('ontouchstart' in window) ? 60 : 30;
var wideScreenWidth = 820;
var wrapper;

window.DEBUG = window.DEBUG || true;

var contentWrapper = function() {
  if (!wrapper || !wrapper.parentNode) wrapper = document.querySelector('.wrapper');
  return wrapper || document.body;
};

var isScrolledToBottom = function() {
  return contentWrapper().offsetHeight - atBottomThreshold < window.innerHeight + document.body.scrollTop;
};

window.addEventListener('resize', function(e) {
  if (window.innerWidth > wideScreenWidth == window.isWideScreen) return;
  window.isWideScreen = !window.isWideScreen;
  riot.update();
});

window.addEventListener('scroll', function(e) {
  if (isScrolledToBottom() == window.isScrolledToBottom) return;
  window.isScrolledToBottom = !window.isScrolledToBottom;
  riot.update();
});

window.loadOffScreen = function(elem) {
  $('img, iframe', elem).each(function() {
    $(this).css('height', '1px').load(function() {
      if (window.isScrolledToBottom) setTimeout(function() { window.scrollToBottom() }, 2);
      $(this).css('height', 'auto');
    });
  });
};

window.nextTick = function(cb) { setTimeout(cb, 5); };

window.isApple = navigator.userAgent.match(/iPhone/i) || navigator.userAgent.match(/iPod/i);
window.isScrolledToBottom = isScrolledToBottom();
window.isTouchDevice = !!('ontouchstart' in window);
window.isWideScreen = window.innerWidth > wideScreenWidth;
window.TODO = function(message) { alert("TODO: " + message); };

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
  return this.replace(/^./, function (match) {
    return match.toUpperCase();
  });
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

window.scrollToBottom = function() {
  document.body.scrollTop = window.innerHeight * 2;
  return this;
};
})(window);
