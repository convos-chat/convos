(function(window) {
  Convos.User = function(attrs) {
    EventEmitter(this);
    this.ws           = new ReconnectingWebSocket(Convos.wsUrl);
    this._api         = Convos.api;
    this._connections = {};
    this._dialogs     = {};
    this._initLocalDialog();

    var prev;
    this.on("updated", function() {
      if (this.email && this.email == prev) return;
      prev = this.email;
      this._listenForEvents();
      this.ws.open(function() {
        this.refresh();
      }.bind(this));
    });
  };

  var proto = Convos.User.prototype;

  // Make the next api method fetch fresh data from server
  proto.fresh = function() {
    this._api.fresh(); return this;
  };

  // Add, get or update a Convos.Connection object on client side
  // Get:    c = user.connection(id)
  // Create: c = user.connection(attrs)
  proto.connection = function(c) {
    if (typeof c != "object") return this._connections[c];
    if (!c.DEFLATE)
      c = new Convos.Connection(c);
    if (this._connections[c.id])
      throw "Connection already exists.";
    c.user                  = this;
    this._connections[c.id] = c;
    this.emit("connection", c);
    return c;
  };

  proto.connections = function() {
    var c = this._connections;
    return Object.keys(c).map(function(k) {
      return c[k];
    });
  };

  proto.currentDialog = function(d) {
    if (d) {
      localStorage.setItem("currentDialog", d.href());
      this._currentDialog = d;
      this.emit("dialogChanged", d);
      return this;
    } else {
      var href = localStorage.getItem("currentDialog") || "chat";
      var current;
      this.dialogs().forEach(function(d) {
        if (d.href() == href)
          current = d;
        if (d != this._currentDialog) this.emit("dialogChanged", d);
        this._currentDialog = d;
      }.bind(this));
      return current || this._localDialog;
    }
  };

  // Get or create a single Convos.Dialog object on client side
  // Get:    d = user.dialog(id)
  // Create: d = user.dialog(attrs)
  proto.dialog = function(obj) {
    if (typeof obj != "object") return this._dialogs[obj];
    obj.connection = this._connections[obj.connection_id];
    var d = new Convos.Dialog(obj);
    if (this._dialogs[d.id])
      throw "Dialog already exists.";
    this._dialogs[d.id] = d;
    this.emit("dialog", d);
    return d;
  };

  proto.dialogs = function() {
    var d = this._dialogs;
    return Object.keys(d).sort().map(function(k) {
      return d[k];
    });
  };

  // Get user settings from server
  // Use user.fresh().load(function() { ... }) to get fresh data from server
  proto.load = function(cb) {
    var self = this;
    this._api.getUser({}, function(err, xhr) {
      if (!err) self.update(xhr.body);
      cb.call(self, err);
    });
    return this;
  };

  // Log out the user
  proto.logout = function(cb) {
    var self = this;
    this._api.http().logoutUser({}, function(err, xhr) {
      if (err) return cb.call(self, err);
      self.email        = "";
      self._dialogs     = {};
      self._connections = {};
      self._api.clearCache()
      self.emit("updated");
      cb.call(self, false);
    });
    return this;
  };

  // Delete a connection on server side and remove it from the user object
  proto.removeConnection = function(connection, cb) {
    var self = this;
    this._api.removeConnection({
      connection_id: connection.id
    }, function(err, xhr) {
      if (err) return cb.call(self, err);
      delete self._connections[connection.id];
      cb.call(self, "");
    });
    return this;
  };

  // Delete a dialog on server side and remove it from the user object
  proto.removeDialog = function(dialog, cb) {
    var self = this;
    this._api.removeDialog(
      {
        connection_id: dialog.connection.id,
        dialog_id:     encodeURIComponent(dialog.id) // Convert "#" to "%23"
      }, function(err, xhr) {
        if (err) return cb.call(self, err);
        delete self._dialogs[dialog.id];
        var first = self.dialogs()[0];
        if (first) self.currentDialog(first);
        cb.call(self, "");
      }
    );
    return this;
  };


  // Refresh related data to the user
  proto.refresh = function() {
    var self = this;
    var first;

    this._api.listConnections({}, function(err, xhr) {
      if (err) return self.emit("error", err);
      xhr.body.connections.forEach(function(c) {
        self.connection(c);
      });
      if (!self.connections().length) return self.emit("refreshed");
      self._api.listDialogs({}, function(err, xhr) {
        if (err) return self.emit("error", err);
        xhr.body.dialogs.forEach(function(d) {
          d     = self.dialog(d);
          first = first || d;
        });
        if (!self.currentDialog().connection && first) self.currentDialog(first);
        self.emit("refreshed");
      });
    });

    return this;
  };

  // Write user settings to server
  proto.save = function(attrs, cb) {
    var self = this;
    if (!cb) return Object.keys(attrs).forEach(function(k) {
        if (typeof this[k] == "function") this[k](attrs[k]);
      }.bind(this));
    this._api.updateUser({
      body: attrs
    }, function(err, xhr) {
      if (err) return cb.call(self, err);
      self.update(attrs);
      cb.call(self, err);
    });
    return this;
  };

  proto.update = function(attrs) {
    var self = this;
    Object.keys(attrs).forEach(function(n) {
      self[n] = attrs[n];
    });
    this.emit("updated");
  };

  proto._initLocalDialog = function() {
    var d = new Convos.Dialog();

    this._localDialog = d;

    d.addMessage({
      message: "Please wait for connections and dialogs to be loaded...",
      hr:      true
    });

    this.once("refreshed", function() {
      if (!this.connections().length) {
        d.addMessage({
          message: "Is this your first time here?",
          hr:      true
        });
        d.addMessage({
          message: 'To add a connection, click the "Edit connections" button in the lower right side menu.'
        });
      } else if (!this.dialogs().length) {
        d.addMessage({
          message: "You are not part of any dialogs.",
          hr:      true
        });
        d.addMessage({
          message: 'To join a dialog, click the "Create dialog" button in the lower right side meny.'
        });
      }
    });
  };

  proto._listenForEvents = function() {
    this.ws.on("json", function(data) {
      var target = this._dialogs[data.tid] || this._connections[data.cid];
      if (target) target.emit(data.type, data);
    }.bind(this));
  };
})(window);
