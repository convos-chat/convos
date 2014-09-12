;(function($) {
  window.convos = window.convos || {};

  convos.emit = function(name) {
    var c = convos.on[name];
    console.log('emit', arguments);
    if (c) c.fireWith(this, $.makeArray(arguments).slice(1));
  };

  convos.on = function(name, cb) {
    if (!convos.on[name]) convos.on[name] = $.Callbacks();
    convos.on[name].add(cb);
    return cb;
  };

  convos.once = function(name, cb) {
    if (!convos.on[name]) convos.on[name] = $.Callbacks();
    var wrapper = function() {
      convos.on[name].remove(wrapper);
      cb.call(this, arguments);
    };
    convos.on[name].add(wrapper);
    return cb;
  };

  convos.unsubscribe = function(name, cb) {
    if (!convos.on[name]) return;
    convos.on[name].remove(cb);
  };
})(jQuery);
