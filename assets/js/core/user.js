(function() {
  Convos.User = function(attrs) {
    this.connections   = [];
    this.dialogs       = [];
    this.email         = "";
    this.notifications = [];
    EventEmitter(this);
  };

  var proto = Convos.User.prototype;

  proto.ensureDialog = function(data) {
    if (!data.dialog_id) data.dialog_id = "convosbot"; // this is a hack to make sure we always have a fallback conversation
    if (data.dialog_id) data.id = data.dialog_id;

    var dialog = this.dialogs.filter(function(d) {
      return d.connection_id == data.connection_id && d.id == data.dialog_id;
    })[0];

    if (!dialog) {
      if (data.connection) data.connection_id = data.connection.id;
      delete data.connection;
      data.id = data.dialog_id;
      data.user = this;
      dialog = new Convos.Dialog(data);
      this.dialogs.push(dialog);
    }

    return dialog;
  };

  proto.getActiveDialog = function(id) {
    return this.dialogs.filter(function(d) { return d.href() == Convos.settings.main; })[0];
  };

  proto.getConnection = function(id) {
    return this.connections.filter(function(c) { return c.id == id; })[0];
  };

  proto.getNotifications = function(cb) {
    var self = this;
    Convos.api.listNotifications({}, function(err, xhr) {
      if (!err) self.notifications = xhr.body.notifications.reverse();
      cb.call(self, err);
    });
  };

  proto.refreshConnections = function(cb) {
    var self = this;
    Convos.api.listConnections({}, function(err, xhr) {
      if (err) return cb.call(self, err);
      self.connections = xhr.body.connections.map(function(c) {
        c.user = self;
        c.id = c.connection_id;
        return new Convos.Connection(c);
      });
      cb.call(self, err);
    });
  };

  proto.refreshDialogs = function(cb) {
    var self = this;
    Convos.api.listDialogs({}, function(err, xhr) {
      if (err) return cb.call(self, err);
      self.dialogs = xhr.body.dialogs.map(function(d) { return self.ensureDialog(d) });
      cb.call(self, err);
    });
  };
})();
