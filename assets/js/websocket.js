(function() {
  window.ReconnectingWebSocket = function(url) {
    this.readyState = WebSocket.CLOSED;
    this.reconnectInterval = 1000;
    this.url = url;
    riot.observable(this);
  };

  var proto = window.ReconnectingWebSocket.prototype;

  proto.close = function(code, reason) {
    if (this._tid) clearTimeout(this._tid);
    if (this._ws  && self._ws.readyState != WebSocket.CLOSED) {
      if (window.DEBUG) console.log('[ReconnectingWebSocket] close ' + code + '/' + reason);
      this._ws.close(code || 1000, reason);
      this.readyState = WebSocket.CLOSING;
    }
    else {
      this.readyState = WebSocket.CLOSED;
    }
    return this;
  };

  proto.open = function(cb) {
    var self = this;

    if (this._ws && this._ws.readyState != WebSocket.CLOSED) {
      if (cb && this._ws.readyState == WebSocket.OPEN) cb.call(this);
      return this;
    }
    if (cb) this.one('open', cb);
    if (window.DEBUG) console.log('[ReconnectingWebSocket] open ' + this.url);

    this.readyState = WebSocket.CONNECTING;
    this._tid = setTimeout(this.open.bind(this), this.reconnectInterval);
    this._ws = new WebSocket(this.url);
    this._ws.onerror = function(e) { console.log('[ReconnectingWebSocket] error:', e); };
    this._ws.onmessage = function(e) {
      self.trigger('message', e);
      if (e.data.match(/^[\{\[]/)) self.trigger('json', JSON.parse(e.data));
    };
    this._ws.onopen = function() { self.readyState = WebSocket.OPEN; self.trigger('open'); };
    this._ws.onclose = function(e) {
      var prevState = self.readyState;
      self.readyState = this.readyState == WebSocket.CLOSING ? WebSocket.CLOSED : WebSocket.CONNECTING;
      if (window.DEBUG) console.log('[ReconnectingWebSocket] close ', e);
      if (e.code != 1000) self.trigger('error', e);
      if (prevState == WebSocket.OPEN) self.trigger('close', e);
      delete self._ws;
      self._tid = setTimeout(self.open.bind(self), self.reconnectInterval);
    };

    return this;
  };

  proto.send = function(data) {
    var ws = this._ws;
    if (typeof data == 'object') data = JSON.stringify(data);
    if (ws && ws.readyState == WebSocket.OPEN) return ws.send(data);
    ws.trigger('error', {code: 1003, reason: 'Cannot send message when not connected.'});
  };

  // bool = obj.stateIs({CONNECTING,CLOSED,CLOSING,OPEN});
  proto.stateIs = function(state) {
    return this.readyState == WebSocket[state];
  };
})();
