;(function(window) {
  window.navigator.is_ios = /(iPad|iPhone|iPod)/.test(navigator.userAgent);
  window.navigator.is_touch_device = /(iPad|iPhone|iPod|Android)/.test(navigator.userAgent); // don't want touch events if the device is a laptop with touch screen

  window.console = window.console || { log: function() { window.console.messages.push(arguments) }, messages: [] };
  window.console._debug = function() { if(window.DEBUG) window.console.log.apply(window.console, arguments) };

  var s4 = function() {
    return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
  };

  window.guid = function() {
    return [ s4() + s4(), s4(), s4(), s4(), s4() + s4() + s4() ].join('-');
  };
})(window);

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
