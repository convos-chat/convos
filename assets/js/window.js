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

String.prototype.ucFirst = function() {
  return this.replace(/^./, function (match) {
    return match.toUpperCase();
  });
};

window.scrollToBottom = function() {
  document.body.scrollTop = window.innerHeight * 2;
  return this;
};
})(window);
