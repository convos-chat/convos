(function() {
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
})();
