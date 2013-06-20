function ReconnectingWebSocket(a) {
  function f(g) {
    c = new WebSocket(a);
    if (b.debug || ReconnectingWebSocket.debugAll) console.debug("ReconnectingWebSocket", "attempt-connect", a);
    var h = c;
    var i = setTimeout(function() {
      if (b.debug || ReconnectingWebSocket.debugAll) console.debug("ReconnectingWebSocket", "connection-timeout", a);
      e = true;
      h.close();
      e = false;
    }, b.timeoutInterval);
    c.onopen = function(c) {
      clearTimeout(i);
      if (b.debug || ReconnectingWebSocket.debugAll) console.debug("ReconnectingWebSocket", "onopen", a);
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
          if (b.debug || ReconnectingWebSocket.debugAll) console.debug("ReconnectingWebSocket", "onclose", a);
          on.close.fire(h, true);
        }
        setTimeout(function() { f(true); }, b.reconnectInterval);
      }
    };
    c.onmessage = function(c) {
      if (b.debug || ReconnectingWebSocket.debugAll) console.debug("ReconnectingWebSocket", "onmessage", a, c.data);
      on.message.fire(c);
    };
    c.onerror = function(c) {
      if (b.debug || ReconnectingWebSocket.debugAll) console.debug("ReconnectingWebSocket", "onerror", a, c);
      on.error.fire(c);
    };
  }
  this.debug = false;
  this.reconnectInterval = 1e3;
  this.timeoutInterval = 2e3;
  var b = this;
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
  this.url = a;
  this.URL = a;
  this.readyState = WebSocket.CONNECTING;
  this.on = function(event, fn) { on[event].add(fn); };
  f(a);
  this.send = function(m) {
    var msg = m;
    return dfd_c.done(function() { return c.send(m); });
  };
  this.close = function() {
    if (c) {
      d = true;
      c.close();
    }
  };
  this.refresh = function() {
    if (c) c.close();
  };
}
ReconnectingWebSocket.debugAll = false;
