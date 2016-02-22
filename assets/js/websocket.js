(function() {
  window.ReconnectingWebSocket = function(url) {
    this.readyState = WebSocket.CLOSED;
    this._reconnectIn = 500;
    this.url = url;
    riot.observable(this);
  };

  var proto = window.ReconnectingWebSocket.prototype;

  // Close the connection to the WebSocket
  // ws = ws.close(1000, reason);
  proto.close = function(code, reason) {
    if (this._tid) clearTimeout(this._tid);
    if (this._ws  && this._ws.readyState != WebSocket.CLOSED) {
      if (window.DEBUG) console.log('[ReconnectingWebSocket] Close ' + code + '/' + reason);
      this._ws.close(code || 1000, reason);
      this.readyState = WebSocket.CLOSING;
    }
    else {
      this.readyState = WebSocket.CLOSED;
    }
    return this;
  };

  // Open a connection to the WebSocket
  // ws = ws.open(function() { ... });
  // ws = ws.open();
  proto.open = function(cb) {
    if (this._ws && this._ws.readyState != WebSocket.CLOSED) {
      if (cb && this._ws.readyState == WebSocket.OPEN) cb.call(this);
      return this;
    }
    if (cb) this.one('open', cb);
    if (window.DEBUG) console.log('[ReconnectingWebSocket] Open ' + this.url);

    this.readyState = WebSocket.CONNECTING;
    this._reconnect(true);
    this._ws = new WebSocket(this.url);
    this._ws.onerror = function(e) { this._reconnect(true); }.bind(this);
    this._ws.onmessage = function(e) {
      this.trigger('message', e);
      if (e.data.match(/^[\{\[]/)) this.trigger('json', JSON.parse(e.data));
    }.bind(this);
    this._ws.onopen = function() {
      this._reconnectIn = 500;
      this.readyState = WebSocket.OPEN;
      this.trigger('open');
    }.bind(this);
    this._ws.onclose = function(e) {
      var prevState = this.readyState;
      this.readyState = this._ws.readyState == WebSocket.CLOSING ? WebSocket.CLOSED : WebSocket.CONNECTING;
      if (window.DEBUG) console.log('[ReconnectingWebSocket] ' + _name(prevState) + ' => ' + _name(this.readyState), e);
      if (prevState == WebSocket.OPEN) this.trigger('close', e);
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
    if (typeof data == 'object') data = JSON.stringify(data);
    if (ws && ws.readyState == WebSocket.OPEN) return ws.send(data);
    throw 'Cannot send message when not connected.';
  };

  proto._reconnect = function(force) {
    if (!force && this._tid) return;
    if (this._tid) clearTimeout(this._tid);
    if (this._reconnectIn > 6000) this._reconnectIn = 500;
    if (window.DEBUG == 2) console.log('[ReconnectingWebSocket] Reconnect after ' + this._reconnectIn);
    this._tid = setTimeout(function() { delete this._tid; this.open() }.bind(this), this._reconnectIn);
    this._reconnectIn += 1000;
  };

  var _name = function(s) {
    switch(s) {
      case WebSocket.CLOSED:     return 'CLOSED';
      case WebSocket.CLOSING:    return 'CLOSING';
      case WebSocket.CONNECTING: return 'CONNECTING';
      case WebSocket.OPEN:       return 'OPEN';
      default:                   return s;
    }
  }
})();
