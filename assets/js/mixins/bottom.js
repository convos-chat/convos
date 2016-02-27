(window['mixin'] = window['mixin'] || {})['bottom'] = function(tag) {
  tag.atBottom = true;
  tag.atBottomThreshold = !!('ontouchstart' in window) ? 60 : 30;

  tag.gotoBottom = function(force) {
    var elem = this.scrollElement;
    if (this.atBottom || force) elem.scrollTop = elem.scrollHeight;
  }.bind(tag);

  tag.detectAtBottomOnScroll = function(e) {
    var elem = this.scrollElement;
    this.atBottom = elem.scrollHeight < elem.offsetHeight + this.atBottomThreshold + elem.scrollTop;
  }.bind(tag);

  tag.moveToBottomOnResize = function(e) {
    if (this._atBottomTid) return;
    var atBottom = this.atBottom;
    this._atBottomTid = setTimeout(
      function() { this.gotoBottom(atBottom); this._atBottomTid = 0; }.bind(this),
      300
    );
  }.bind(tag);

  tag.on('update', function() {
    var elem = this.scrollElement;
    this.atBottom = elem.scrollHeight < elem.offsetHeight + this.atBottomThreshold + elem.scrollTop;
  });

  tag.on('mount', function() {
    window.addEventListener('resize', this.moveToBottomOnResize);
    this.scrollElement.addEventListener('scroll', this.detectAtBottomOnScroll);
  });

  tag.on('updated', tag.gotoBottom);

  tag.on('unmount', function() {
    window.removeEventListener('resize', this.moveToBottomOnResize);
    this.scrollElement.removeEventListener('scroll', this.detectAtBottomOnScroll);
  });

  return tag;
};
