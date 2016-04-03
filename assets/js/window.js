(function() {
  window.isApple         = navigator.userAgent.match(/iPhone/i) || navigator.userAgent.match(/iPod/i);
  window.isTouchDevice   = !!("ontouchstart" in window);
  window.isWideScreen    = window.innerWidth > window.wideScreenWidth;
  window.wideScreenWidth = 820;
  window.DEBUG           = window.DEBUG || true;

  window.nextTick = function(cb) {
    setTimeout(cb, 1);
  };

  NodeList.prototype.$forEach = Array.prototype.forEach;

  Element.prototype.$remove = function() {
    this.parentElement.removeChild(this);
  };
})();
