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
    data.id = data.connection_id;
    var connection = this.connections.filter(function(c) { return c.id == data.id; })[0];

    if (!connection) {
      data.user = this;
      connection = new Convos.Connection(data);
      this.connections.push(connection);
    }

    return connection.update(data);
  };

  proto.ensureDialog = function(data) {
    if (!data.dialog_id) data.dialog_id = "convosbot"; // this is a hack to make sure we always have a fallback conversation
    if (data.dialog_id) data.id = data.dialog_id;

    var dialog = this.dialogs.filter(function(d) {
      return d.connection_id == data.connection_id && d.id == data.dialog_id;
    })[0];

    if (!dialog) {
      if (data.connection && !data.connection_id) data.connection_id = data.connection.id;
      if (!data.name) data.name = data.from || data.dialog_id;
      delete data.connection;
      data.id = data.dialog_id;
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
    return this.connections.filter(function(c) { return c.id == id; })[0];
  };

  proto.refresh = function() {
    var self = this;
    Convos.api.getUser(
      {connections: true, dialogs: true, notifications: true},
      function(err, xhr) {
        if (err) return self.currentPage = "convos-login";
        self.email = xhr.body.email;
        xhr.body.connections.forEach(function(c) { self.ensureConnection(c) });
        xhr.body.dialogs.forEach(function(d) {
          d = self.ensureDialog(d);
          if (d.active) d.emit("active");
        });
        self.notifications = xhr.body.notifications.reverse();
        self.unread = xhr.body.unread || 0;
        self.currentPage = "convos-chat";
      }
    );
  };

  proto._setupWebSocket = function() {
    var self = this;
    var ws = new ReconnectingWebSocket(Convos.wsUrl);

    this.ws = ws;
    this._keepAlive = setInterval(function() { if (ws.is("open")) ws.send('{}'); }, 10000);

    this.ws.on("close", function() {
      self.connections.forEach(function(c) { c.state = "unreachable"; });
      self.dialogs.forEach(function(d) { d.frozen = "No internet connection?"; d.activated = 0; });
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
