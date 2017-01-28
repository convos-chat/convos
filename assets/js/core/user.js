(function() {
  Convos.User = function(attrs) {
    EventEmitter(this);
    this.connections = [];
    this.currentPage = "";
    this.dialogs = [];
    this.email = "";
    this.notifications = [];
    this.unread = 0;
    this._keepAliveTid = setInterval(this._keepAlive(), 20000);
  };

  var proto = Convos.User.prototype;

  proto.ensureConnection = function(data) {
    var connection = this.connections.filter(function(c) { return c.connection_id == data.connection_id; })[0];

    if (!connection) {
      if (window.DEBUG > 1) console.log("[ensureConnection] ", JSON.serialize(data));
      data.user = this;
      connection = new Convos.Connection(data);
      this.connections.push(connection);
      this.ensureDialog({
        connection_id: connection.connection_id,
        dialog_id: "",
        name: connection.name,
        is_private: false
      });
    }

    return connection.update(data);
  };

  proto.ensureDialog = function(data) {
    var dialog = this.dialogs.filter(function(d) {
      return d.connection_id == data.connection_id && d.dialog_id == data.dialog_id;
    })[0];

    if (!dialog) {
      if (window.DEBUG > 1) console.log("[ensureDialog] ", JSON.serialize(data));
      if (data.connection && !data.connection_id) data.connection_id = data.connection.connection_id;
      if (!data.name) data.name = data.from || data.dialog_id;
      delete data.connection;
      data.user = this;
      dialog = new Convos.Dialog(data);
      this.dialogs.push(dialog);
    }

    return dialog.update(data);
  };

  proto.getActiveDialog = function() {
    return this.dialogs.filter(function(d) { return d.href() == Convos.settings.main; })[0];
  };

  proto.getLastActiveDialog = function() {
    return this.dialogs.sort(function(a, b) { return a.lastRead.valueOf - b.lastRead.valueOf; })[0];
  };

  proto.getConnection = function(id) {
    if (typeof id == "undefined") {
      var dialog = this.getLastActiveDialog();
      return dialog ? dialog.connection() : this.connections[0];
    }
    else {
      return this.connections.filter(function(c) { return c.connection_id == id; })[0];
    }
  };

  proto.refresh = function() {
    var self = this;

    if (window.DEBUG) console.log("[WebSocket] readyState is " + this._wsState());
    if (this._wsState() == "OPEN") return console.trace("[WebSocket] Already open!");
    if (this._refreshTid) clearTimeout(this._refreshTid);

    this.ws = new WebSocket(Convos.wsUrl);

    this.ws.onopen = function() {
      self.send({method: "get_user", connections: true, dialogs: true, notifications: true});
    };

    this.ws.onclose = this.ws.onerror = function(e) {
      if (window.DEBUG) console.log("[WebSocket]", e);
      if (!self.email) return self.currentPage = "convos-login";
      self._refreshTid = setTimeout(self.refresh.bind(self), 1000);
      self.connections.forEach(function(c) { c.update({state: "unreachable"}); });
      self.dialogs.forEach(function(d) { d.update({frozen: "No internet connection?"}); });
    };

    this.ws.onmessage = function(e) {
      if (window.DEBUG > 1) console.log("[WebSocket] " + e.data);
      var data = JSON.parse(e.data);

      if (data.connection_id && data.event) {
        self.getConnection(data.connection_id).emit(data.event, data);
      }
      else if (data.email) {
        if (window.DEBUG) console.log("[Convos] User " + data.email + " is logged in");
        data.connections.forEach(function(c) { self.ensureConnection(c); });
        data.dialogs.forEach(function(d) { self.ensureDialog(d); });
        self.email = data.email;
        self.notifications = data.notifications.reverse();
        self.unread = data.unread || 0;
        self.currentPage = "convos-chat";
        self.emit("ready");
      }
    };
  };

  proto.send = function(data) {
    this.ws.send(JSON.stringify(data));
  };

  proto._keepAlive = function() {
    var self = this;
    return function() {
      if (self._wsState() == "OPEN") self.ws.send('{}');
    };
  };

  proto._wsState = function() {
    if (!this.ws) return "UNDEFINED";
    switch (this.ws.readyState) {
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
