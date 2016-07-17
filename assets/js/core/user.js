(function() {
  Convos.User = function(attrs) {
    this.connections   = [];
    this.dialogs       = [];
    this.email         = "";
    this.notifications = [];

    // Local chat bot. could probably be moved to backend
    // if we make Convos::Core::Connection::Convos
    this.convosDialog = new Convos.Dialog({
      is_private: true,
      name:       "convosbot"
    });
  };

  var proto = Convos.User.prototype;

  proto.getConnection = function(id) {
    return this.connections.filter(function(c) {
      return c.id == id;
    })[0];
  };

  proto.getDialog = function(id) {
    return this.dialogs.filter(function(d) {
      return d.id == id;
    })[0];
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
      self.connections = [];
      xhr.body.connections.forEach(function(c) {
        c.user = self;
        self.connections.push(new Convos.Connection(c));
      });
      cb.call(self, err);
    });
  };

  proto.refreshDialogs = function(cb) {
    var self = this;
    var hasActive = false;
    Convos.api.listDialogs({}, function(err, xhr) {
      if (err) return cb.call(self, err);
      self.dialogs = [self.convosDialog];
      xhr.body.dialogs.forEach(function(d) {
        d.connection = self.getConnection(d.connection_id);
        d.user       = self;
        d            = new Convos.Dialog(d); // need to be done after d.connection = and d.user =
        if (d.active()) hasActive = true;
        self.dialogs.push(d);
      });
      if (!hasActive) self.dialogs[0].active(true);
      cb.call(self, err);
    });
  };
})();
