// this code is originally from https://github.com/joewalnes/reconnecting-websocket
window.ws = function(a) {
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
      b.onopen(c);
      while(b.buffer.length) b.send(b.buffer.shift());
    };
    c.onclose = function(h) {
      clearTimeout(i);
      c = null;
      if (d) {
        b.readyState = WebSocket.CLOSED;
        b.onclose(h, false);
      } else {
        b.readyState = WebSocket.CONNECTING;
        if (!g && !e) {
          if (b.debug) console.debug("ReconnectingWebSocket", "onclose", a);
          b.onclose(h, true);
        }
        setTimeout(function() { f(true); }, b.reconnectInterval);
      }
    };
    c.onmessage = function(m) {
      if (b.debug) console.debug("ReconnectingWebSocket", "onmessage", a, m.data);
      b.onmessage(m);
    };
    c.onerror = function(e) {
      if (b.debug) console.debug("ReconnectingWebSocket", "onerror", a, e);
      on.onerror(e);
    };
  }
  var d = false;
  var e = false;
  var c;
  var b = {
    buffer: [],
    debug: false,
    onerror: function(e) { console.log(b.url + ' ! ' + e); },
    onopen: function(c) { console.log(b.url + ' : open'); },
    onmessage: function(m) { console.log(b.url + ' < ' + m); },
    onclose: function(e) { console.log(b.url + ' : close'); },
    reconnectInterval: 2e3,
    timeoutInterval: 5e3,
    readyState: WebSocket.CONNECTING,
    url: a,
    close: function() { if(!c) return false; c.close(); return(d = true); },
    send: function(m) {
      if(b.readyState == WebSocket.OPEN) {
        c.send(m);
      }
      else {
        b.buffer.push(m);
      }
      return b
    }
  };
  f(a);
  return b;
};
