(function() {
  window.ReconnectingWebSocket = function(url) {
    this.readyState = WebSocket.CLOSED;
    this.reconnectInterval = 1000;
    this.url = url;
    console.log('ReconnectingWebSocket: ' + this.url);
    riot.observable(this);
  };

  var proto = window.ReconnectingWebSocket.prototype;

  proto.close = function(code, reason) {
    if (this._tid) clearTimeout(this._tid);
    if (this._ws  && self._ws.readyState != WebSocket.CLOSED) {
      this._ws.close(code || 1000, reason);
      this.readyState = WebSocket.CLOSING;
    }
    else {
      this.readyState = WebSocket.CLOSED;
    }
    return this;
  };

  proto.open = function() {
    var self = this;

    if (self._ws && self._ws.readyState != WebSocket.CLOSED) return self;
    self.readyState = WebSocket.CONNECTING;
    self._tid = setTimeout(self.open.bind(self), self.reconnectInterval);
    self._ws = new WebSocket(this.url);
    self._ws.onerror = function(e) { console.log('websocket error:', e); };
    self._ws.onmessage = function(e) { self.trigger('message', e); };
    self._ws.onopen = function() { self.readyState = WebSocket.OPEN; self.trigger('open'); };
    self._ws.onclose = function(e) {
      var prevState = self.readyState;
      console.log('websocket close:', e);
      self.readyState = this.readyState == WebSocket.CLOSING ? WebSocket.CLOSED : WebSocket.CONNECTING;
      if (e.code != 1000) self.trigger('error', e);
      if (prevState == WebSocket.OPEN) self.trigger('close', e);
      delete self._ws;
      self._tid = setTimeout(self.open.bind(self), self.reconnectInterval);
    };
    return self;
  };

  proto.send = function(obj) {
    var ws = this._ws;
    if (typeof obj == 'string') obj = {data: obj};
    if (ws && ws.readyState == WebSocket.OPEN) return ws.send(JSON.stringify(obj));
    obj.reason = 'Cannot send message when not connected.';
    obj.code = 1003; // TODO
    ws.trigger('error', obj);
  };

  // bool = obj.stateIs({CONNECTING,CLOSED,CLOSING,OPEN});
  proto.stateIs = function(state) {
    return this.readyState == WebSocket[state];
  };
})();
