;(function($) {
  var at_bottom_threshold = 40;
  var $heigth_from, $win, base_url;

  $.fn.scrollToBottom = function() {
    $(this).scrollTop($heigth_from.height());
    return this;
  };

  $.url_for = function() {
    var args = $.makeArray(arguments);
    if(!base_url) base_url = $('script[src$="jquery.js"]').get(0).src.replace(/\/js\/[^\/]+$/, '');
    args.unshift(base_url);
    return args.join('/').replace(/#/g, '%23')
  };

  // this code is originally from https://github.com/joewalnes/reconnecting-websocket
  $.ws = function(a) {
    function f(g) {
      c = new WebSocket(a);
      if (b.debug) console.debug("ReconnectingWebSocket", "attempt-connect", a);
      var h = c;
      var i = setTimeout(function() {
        if (b.debug) console.debug("ReconnectingWebSocket", "connection-timeout", a);
        e = true;
        h.close();
        e = false;
      }, b.timeoutInterval);
      c.onopen = function(c) {
        clearTimeout(i);
        if (b.debug) console.debug("ReconnectingWebSocket", "onopen", a);
        b.readyState = WebSocket.OPEN;
        g = false;
        on.open.fire(c);
        dfd_c.resolve(c);
      };
      c.onclose = function(h) {
        clearTimeout(i);
        c = null;
        dfd_c = $.Deferred();
        if (d) {
          b.readyState = WebSocket.CLOSED;
          on.close.fire(h, false);
        } else {
          b.readyState = WebSocket.CONNECTING;
          if (!g && !e) {
            if (b.debug) console.debug("ReconnectingWebSocket", "onclose", a);
            on.close.fire(h, true);
          }
          setTimeout(function() { f(true); }, b.reconnectInterval);
        }
      };
      c.onmessage = function(c) {
        if (b.debug) console.debug("ReconnectingWebSocket", "onmessage", a, c.data);
        on.message.fire(c);
      };
      c.onerror = function(c) {
        if (b.debug) console.debug("ReconnectingWebSocket", "onerror", a, c);
        on.error.fire(c);
      };
    }
    var d = false;
    var e = false;
    var c;
    var dfd_c = $.Deferred();
    var on = {
      close: $.Callbacks(),
      error: $.Callbacks(),
      message: $.Callbacks(),
      open: $.Callbacks(),
      ready: $.Callbacks()
    };
    var b = {
      debug: false,
      reconnectInterval: 1e3,
      timeoutInterval: 2e3,
      readyState: WebSocket.CONNECTING,
      url: a,
      close: function() { if(!c) return false; c.close(); return(d = true); },
      on: function(event, fn) { on[event].add(fn); },
      send: function(m) { var msg = m; return dfd_c.done(function() { return c.send(m); }); }
    };
    f(a);
    return b;
  };

  $(document).ready(function() {
    $heigth_from = $('div.wrapper').length ? $('div.wrapper') : $('body');
    $win = $(window).data('at_bottom', false);

    setTimeout(function() { $(document).trigger('completely_ready'); }, 200);
    $(document).data('heigth_from', $heigth_from);

    $win.on('scroll', function() {
      var at_bottom = $win.scrollTop() + $win.height() > $heigth_from.height() - at_bottom_threshold;
      $win.data('at_bottom', at_bottom);
    });
  });

})(jQuery);

// super cheap sorted set implementation
window.sortedSet = function() { this.set = {}; return this; };
window.sortedSet.prototype.add = function(score, member) { this.set[member] = score; return this; };
window.sortedSet.prototype.clear = function() { this.set = {}; return this; };
window.sortedSet.prototype.rem = function(member) { delete this.set[member]; return this; };
window.sortedSet.prototype.revrange = function(start, stop) {
  var k, res = [], self = this;
  for(k in self.set) res.push(k);
  if(start < 0) start = res.length + start;
  if(stop < 0) stop = res.length + stop + 1;
  return res.sort(function(a, b) { return self.set[b] - self.set[a]; }).splice(start, stop);
};

