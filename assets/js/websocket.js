(function() {
  window.ReconnectingWebSocket = function(url) {
    this.readyState   = WebSocket.CLOSED;
    this._reconnectIn = 500;
    this.url          = url;
    EventEmitter(this);
  };

  var proto = window.ReconnectingWebSocket.prototype;

  // Close the connection to the WebSocket
  // ws = ws.close(1000, reason);
  proto.close = function(code, reason) {
    if (this._tid) clearTimeout(this._tid);
    if (this._ws && this._ws.readyState != WebSocket.CLOSED) {
      if (window.DEBUG) console.log("[ReconnectingWebSocket] Close " + code + "/" + reason);
      this._ws.close(code || 1000, reason);
      this._state(WebSocket.CLOSING);
    } else {
      this._state(WebSocket.CLOSED);
    }
    return this;
  };

  proto.is = function(state) {
    return _name(this.readyState) == state.toUpperCase();
  };

  // Open a connection to the WebSocket
  // ws = ws.open(function() { ... });
  // ws = ws.open();
  proto.open = function() {
    if (this._ws && this._ws.readyState != WebSocket.CLOSED)
      return this;
    if (window.DEBUG) console.log("[ReconnectingWebSocket] Open " + this.url);

    this._state(WebSocket.CONNECTING);
    this._reconnect(true);
    this._ws         = new WebSocket(this.url);
    this._ws.onerror = function(e) {
      this._reconnect(true);
    }.bind(this);
    this._ws.onmessage = function(e) {
      this.emit("message", e);
      if (e.data.match(/^[\{\[]/)) this.emit("json", JSON.parse(e.data));
    }.bind(this);
    this._ws.onopen = function() {
      this._reconnectIn = 500;
      this._state(WebSocket.OPEN);
    }.bind(this);
    this._ws.onclose = function(e) {
      var prevState = this.readyState;
      this._state(this._ws.readyState == WebSocket.CLOSING ? WebSocket.CLOSED : WebSocket.CONNECTING);
      if (window.DEBUG) console.log("[ReconnectingWebSocket] " + _name(prevState) + " => " + _name(this.readyState), e);
      if (prevState == WebSocket.OPEN) this.emit("close", e);
      if (this.readyState == WebSocket.CONNECTING) this._reconnect(false);
      delete this._ws;
    }.bind(this);

    return this;
  };

  // Send data to the WebSocket
  // ws = ws.send(str);
  // ws = ws.send({foo: 123});
  proto.send = function(data) {
    var ws = this._ws;
    if (typeof data == "object")
      data = JSON.stringify(data);
    if (ws && ws.readyState == WebSocket.OPEN) return ws.send(data);
    throw "Cannot send message when not connected.";
  };

  proto._reconnect = function(force) {
    if (!force && this._tid) return;
    if (this._tid) clearTimeout(this._tid);
    if (this._reconnectIn > 6000)
      this._reconnectIn = 500;
    if (window.DEBUG == 2) console.log("[ReconnectingWebSocket] Reconnect after " + this._reconnectIn);
    this._tid = setTimeout(function() {
      delete this._tid;
      this.open();
    }.bind(this), this._reconnectIn);
    this._reconnectIn += 1000;
  };

  proto._state = function(state) {
    this.readyState = state;
    this.emit(_name(state).toLowerCase());
  };

  var _name = function(s) {
    switch (s) {
      case WebSocket.CLOSED:
        return "CLOSED";
      case WebSocket.CLOSING:
        return "CLOSING";
      case WebSocket.CONNECTING:
        return "CONNECTING";
      case WebSocket.OPEN:
        return "OPEN";
      default:
        return "" + s;
    }
  };
})();
