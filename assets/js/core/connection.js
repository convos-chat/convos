(function() {
  Convos.Connection = function(attrs) {
    EventEmitter(this);
    this.id       = "";
    this.name     = "";
    this.me       = {nick: ""};
    this.protocol = "unknown";
    this.state    = "disconnected";
    this.url      = "";
    this._api     = Convos.api;
    this.on("message", function(data) { this.user.ensureDialog(data).addMessage(data); });
    this.on("state", this._onState);
    if (attrs) this.update(attrs);
  };

  var proto = Convos.Connection.prototype;

  proto.getDialog = function(dialog_id) {
    return this.user.dialogs.filter(function(d) {
      return d.connection_id == this.id && d.id == dialog_id;
    }.bind(this))[0];
  };

  proto.href = function(action) {
    return ["#connection", this.protocol, this.name, action].join("/");
  };

  // Human readable version of state
  proto.humanState = function() {
    return this.state.ucFirst();
  };

  proto.nick = function() {
    return this.me.nick ? this.me.nick : this.url.parseUrl().query.nick || "";
  };

  proto.notice = function(message) {
    this.emit("message", {
      from:    this.id,
      message: message,
      type:    "notice"
    });
  };

  // Remove this connection from the backend
  proto.remove = function(cb) {
    var self = this;
    this._api.removeConnection({connection_id: this.id}, function(err, xhr) {
      if (!err) {
        self.user.connections = self.user.connections.filter(function(c) {
          return c.id != self.id;
        });
      }
      cb.call(self, err);
    });
    return this;
  };

  // Get list of available rooms on server
  proto.rooms = function(cb) {
    var self = this;
    this._api.roomsByConnection(
      {
        connection_id: this.id
      }, function(err, xhr) {
        if (err) return cb.call(self, err, []);
        cb.call(self, err, xhr.body.rooms);
      }
    );
    return this;
  };

  // Write connection settings to server
  proto.save = function(cb) {
    var self = this;

    // It is currently not possible to specify "name"
    var attrs = {
      url: this.url
    };

    if (this.id) {
      this._api.updateConnection(
        {
          body:          attrs,
          connection_id: this.id
        }, function(err, xhr) {
          if (err) return cb.call(self, err);
          self.update(xhr.body);
          cb.call(self, err);
        }
      );
    } else {
      this._api.createConnection({
        body: attrs
      }, function(err, xhr) {
        if (err) return cb.call(self, err);
        self.update(xhr.body);
        self.user.connections.push(self);
        cb.call(self, err);
      });
    }
    return this;
  };

  proto.send = function(command, dialog) {
    var self = this;
    this._api.commandFromUser(
      {
        body: {
          command:       command,
          connection_id: this.id,
          dialog_id:     dialog ? dialog.id : ""
        }
      }, function(err, xhr) {
        var action = command.match(/^\/(\w+)\s*(\S*)/);
        if (err) {
          self.emit("message", {
            type:    "error",
            message: 'Could not send "' + command + '": ' + err[0].message
          });
        }
        else if (action) {
          var handler = "_completed" + action[1].toLowerCase().ucFirst();
          if (!dialog) dialog = self.getDialog(action[2]); // action = ["...", "close", "#foo" ]
          if (dialog) xhr.body.dialog_id = dialog.id;
          if (DEBUG) console.log("[completed:" + action[1] + "] " + JSON.stringify(xhr.body));
          return self[handler] ? self[handler](xhr.body) : console.log("No handler for " + handler);
        }
      }
    );
    return this;
  };

  proto.update = function(attrs) {
    var self = this;
    Object.keys(attrs).forEach(function(n) {
      self[n] = attrs[n];
    });
  };

  proto._completedClose = proto._completedPart = function(data) {
    this.user.dialogs = this.user.dialogs.filter(function(d) {
      return d.connection_id != this.id || d.id != data.dialog_id;
    }.bind(this));
    Convos.settings.main = this.user.dialogs.length ? this.user.dialogs[0].href() : "";
  };

  proto._completedJoin = proto._completedJ = function(data) {
    Convos.settings.main = this.user.ensureDialog(data).href();
  };

  proto._completedWhois = function(data) {
    var channels = Object.keys(data.channels).sort();
    data.message = data.nick;

    if (data.idle_for) {
      data.message += " has been idle for " + data.idle_for + " seconds in ";
    } else {
      data.message += " is active in ";
    }

    while (channels.length) {
      var name = channels.shift();
      var sep  = channels.length == 1 ? " and " : channels.length ? ", " : ".";
      data.message += name + "" + sep;
    }

    this.notice(data.message);
  };

  proto._onState = function(data) {
    if (DEBUG) console.log("[state:" + data.type + "] " + this.href() + ":" + data.type + " = " + JSON.stringify(data));
    switch (data.type) {
      case "connection":
        var msg = data.state + '"';
        this.state = data.state;
        msg += data.message ? ': ' + data.message : ".";
        this.notice('Connection state changed to "' + msg);
      case "frozen":
        this.user.ensureDialog(data).frozen = data.frozen;
        break;
      case "me":
        this.me.nick = data.nick;
        break;
      case "nick_change":
        this.user.dialogs.forEach(function(d) {
          if (d.connection_id == data.connection_id) d.emit("state", data);
        });
        break;
      case "part":
        this.user.dialogs.forEach(function(d) {
          if (d.connection_id == data.connection_id) d.emit("state", data);
        });
        break;
    }
  };
})();
