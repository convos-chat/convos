(function() {
  Convos.User = function(attrs) {
    EventEmitter(this);
    this.connections   = [];
    this.currentPage   = "";
    this.dialogs       = [];
    this.email         = "";
    this.notifications = [];
    this.unread        = 0;
    this._setupWebSocket();
  };

  var proto = Convos.User.prototype;

  proto.ensureConnection = function(data) {
    var connection = this.connections.filter(function(c) { return c.connection_id == data.connection_id; })[0];

    if (!connection) {
      if (window.DEBUG == 2) console.log("[ensureConnection] ", JSON.serialize(data));
      data.user = this;
      connection = new Convos.Connection(data);
      this.connections.push(connection);
      this.ensureDialog({
        connection_id: connection.connection_id,
        dialog_id: "",
        name: connection.name,
        frozen: connection.state == "connected" ? "" : connection.state
      });
    }

    return connection.update(data);
  };

  proto.ensureDialog = function(data) {
    var dialog = this.dialogs.filter(function(d) {
      return d.connection_id == data.connection_id && d.dialog_id == data.dialog_id;
    })[0];

    if (!dialog) {
      if (window.DEBUG == 2) console.log("[ensureDialog] ", JSON.serialize(data));
      if (data.connection && !data.connection_id) data.connection_id = data.connection.connection_id;
      if (!data.name) data.name = data.from || data.dialog_id;
      delete data.connection;
      data.user = this;
      dialog = new Convos.Dialog(data);
      this.dialogs.push(dialog);
    }

    return dialog.update(data);
  };

  proto.getActiveDialog = function(id) {
    return this.dialogs.filter(function(d) { return d.href() == Convos.settings.main; })[0];
  };

  proto.getConnection = function(id) {
    return this.connections.filter(function(c) { return c.connection_id == id; })[0];
  };

  proto.refresh = function() {
    var self = this;
    Convos.api.getUser(
      {connections: true, dialogs: true, notifications: true},
      function(err, xhr) {
        if (err) return self.currentPage = "convos-login";
        if (!self.email) self.ws.open(); // first time
        self.email = xhr.body.email;
        xhr.body.connections.forEach(function(c) { self.ensureConnection(c) });
        xhr.body.dialogs.forEach(function(d) { d = self.ensureDialog(d); });
        self.notifications = xhr.body.notifications.reverse();
        self.unread = xhr.body.unread || 0;
        self.currentPage = "convos-chat";
        self.connections.forEach(function(c) { c.emit("connect"); });
        self.dialogs.forEach(function(d) { d.emit("connect"); });
      }
    );
  };

  proto._setupWebSocket = function() {
    var self = this;
    var ws = new ReconnectingWebSocket(Convos.wsUrl);

    this.ws = ws;
    this._keepAlive = setInterval(function() { if (ws.is("open")) ws.send('{}'); }, 20000);

    this.ws.on("close", function() {
      self.connections.forEach(function(c) { c.update({state: "unreachable"}).emit("disconnect"); });
      self.dialogs.forEach(function(d) { d.update({frozen: "No internet connection?"}).emit("disconnect"); });
    });

    // Need to install the refresh handler after the first close event
    this.ws.once("close", function() {
      self.ws.on("open", self.refresh.bind(self));
    });

    this.ws.on("json", function(data) {
      if (!data.connection_id) return console.log("[ws] json=" + JSON.stringify(data));
      var c = self.getConnection(data.connection_id);
      return c ? c.emit(data.event, data) : console.log("[ws:" + data.connection_id + "] json=" + JSON.stringify(data));
    });
  };
})();
