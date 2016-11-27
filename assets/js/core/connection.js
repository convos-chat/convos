(function() {
  Convos.Connection = function(attrs) {
    EventEmitter(this);
    this.connection_id = "";
    this.name = "";
    this.me = {nick: ""};
    this.message = "";
    this.on_connect_commands = [];
    this.protocol = "unknown";
    this.sendTimeout = 5000; // is this long enough?
    this.state = "disconnected";
    this.url = "";
    this.on("message", this._onMessage);
    this.on("sent", this._onSent);
    this.on("state", this._onState);
    if (attrs) this.update(attrs);
  };

  var aliases = {};
  var proto = Convos.Connection.prototype;

  Convos.commands.forEach(function(cmd) {
    (cmd.aliases || [cmd.command]).forEach(function(a) {
      aliases[a] = cmd.alias_for ? cmd.alias_for : "/" + cmd.command;
    });
  });

  proto.dialogs = function() {
    var id = this.connection_id;
    return this.user.dialogs.filter(function(d) { return d.connection_id == id; });
  };

  proto.getDialog = function(dialog_id) {
    return this.user.dialogs.filter(function(d) {
      return d.connection_id == this.connection_id && d.dialog_id == dialog_id;
    }.bind(this))[0];
  };

  proto.href = function() {
    return ["#connection", this.protocol, this.name].join("/");
  };

  // Human readable version of state
  proto.humanState = function() {
    return this.state.ucFirst();
  };

  proto.nick = function() {
    return this.me.nick ? this.me.nick : this.url.parseUrl().query.nick || "";
  };

  proto.notice = function(message) {
    var dialog = this.user.getActiveDialog();
    if (dialog) dialog.addMessage({from: this.connection_id, message: message, type: "notice"});
  };

  // Remove this connection from the backend
  proto.remove = function(cb) {
    var self = this;
    Convos.api.removeConnection({connection_id: this.connection_id}, function(err, xhr) {
      if (!err) {
        self.off("message").off("state");
        self.user.connections = self.user.connections.filter(function(c) {
          return c.connection_id != self.connection_id;
        });
        self.user.dialogs = self.user.dialogs.filter(function(d) {
          return d.connection_id != self.connection_id;
        });
      }
      cb.call(self, err);
    });
    return this;
  };

  // Get list of available rooms on server
  proto.rooms = function(cb) {
    var self = this;
    Convos.api.rooms({connection_id: this.connection_id}, function(err, xhr) {
      if (err) return cb.call(self, err, []);
      cb.call(self, err, xhr.body.rooms);
    });
    return this;
  };

  // Write connection settings to server
  proto.save = function(cb) {
    var self = this;

    // It is currently not possible to specify "name"
    var attrs = {
      url: this.url,
      on_connect_commands: this.on_connect_commands,
    };

    if (this.connection_id) {
      Convos.api.updateConnection(
        {
          body:          attrs,
          connection_id: this.connection_id
        }, function(err, xhr) {
          if (err) return cb.call(self, err);
          self.update(xhr.body);
          cb.call(self, err);
        }
      );
    } else {
      Convos.api.createConnection({
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

  proto.send = function(message, dialog, cb) {
    var self = this;
    var action = message.match(/^\/(\w+)\s*(\S*)/) || ['', 'message', ''];
    var id;

    if (aliases[action[1]]) {
      message = message.replace(/^\/(\w+)/, aliases[action[1]]);
      action = message.match(/^\/(\w+)\s*(\S*)/) || ['', 'message', ''];
    }

    if (action[1] == 'query') {
      if (action[2]) {
        Convos.settings.main = this.user.ensureDialog({connection_id: this.connection_id, dialog_id: action[2]}).href();
      }
      return;
    }

    if (!dialog) dialog = this.getDialog(action[2]); // action = ["...", "close", "#foo" ]
    if (!dialog) dialog = this.user.getActiveDialog();

    id = setTimeout(
      function() {
        self.off("sent-" + id);
        self.user.getActiveDialog().addMessage({
          type: "error",
          message: "Could not send message to " + (dialog ? dialog.name : this.connection_id) + ": " + message,
        });
      },
      self.sendTimeout
    );

    // Handle echo back from backend
    var handler = "_sent" + action[1].toLowerCase().ucFirst();
    this.once("sent-" + id, function(msg) {
      if (cb) return cb.call(self, msg);
      self[self[handler] ? handler : "_onError"](msg);
    });

    this.user.ws.send({
      id:            id,
      method:        "send",
      message:       message,
      connection_id: this.connection_id,
      dialog_id:     dialog ? dialog.dialog_id : ""
    });

    return this;
  };

  proto.update = function(attrs) {
    var self = this;
    Object.keys(attrs).forEach(function(n) {
      self[n] = attrs[n];
    });
  };

  proto._onError = function(msg) {
    if (msg.errors) {
      var dialog = this.user.getActiveDialog();
      if (dialog) dialog.addMessage({from: this.connection_id, type: "error", message: msg.message + ": " + msg.errors[0].message});
    }
  };

  proto._onMessage = function(msg) {
    if (msg.errors) return this._onError(msg);
    msg.frozen = "";
    return this.user.ensureDialog(msg).addMessage(msg);
  };

  proto._onSent = function(msg) {
    if (DEBUG) console.log("[sent] " + JSON.stringify(msg));
    clearTimeout(msg.id);
    this.emit("sent-" + msg.id, msg).off("sent-" + msg.id);
  };

  proto._sentClose = function(msg) {
    if (msg.errors) return this._onError(msg);
    this.user.dialogs = this.user.dialogs.filter(function(d) {
      return d.connection_id != this.connection_id || d.dialog_id != msg.dialog_id;
    }.bind(this));
    Convos.settings.main = this.user.dialogs.length ? this.user.dialogs[0].href() : "";
  };

  proto._sentNames = function(msg) {
    if (msg.errors) return this._onError(msg);
    msg.type = "participants";
    this.user.ensureDialog(msg).addMessage(msg);
  };

  // part will not close the dialog
  proto._sentPart = function(msg) {
    if (msg.errors) return this._onError(msg);
    this.user.getActiveDialog().addMessage({
      "type": "notice",
      "message": "You parted " + msg.dialog_id + "."
    });
  };

  proto._sentJoin = function(msg) {
    var dialog = this.user.ensureDialog(msg);
    dialog.emit("active").emit("join");
    Convos.settings.main = dialog.href();
  };

  proto._sentReconnect = function(msg) {
    this.notice('Reconnecting to ' + this.connection_id + '...');
  };

  proto._sentTopic = function(msg) {
    if (msg.errors) return this._onError(msg);
    if (!msg.hasOwnProperty("topic")) return;
    var dialog = this.user.ensureDialog(msg);
    var next = {from: this.connection_id, type: "notice"};
    if (msg.topic) {
      next.message = "Topic for " + dialog.name + " is: " + msg.topic;
    }
    else {
      next.message = "There is no topic for " + dialog.name + ".";
    }
    dialog.addMessage(next);
  };

  proto._sentWhois = function(msg) {
    if (msg.errors) return this._onError(msg);
    var dialog = this.user.getActiveDialog();
    if (!dialog) return;
    msg.from = this.connection_id;
    msg.type = "whois";
    dialog.addMessage(msg);
  };

  proto._onState = function(data) {
    if (DEBUG) console.log("[state:" + data.type + "] " + this.href() + " = " + JSON.stringify(data));

    switch (data.type) {
      case "connection":
        var msg = data.state + '"';
        msg += data.message ? ': ' + data.message : ".";
        this.state = data.state;
        this.message = data.message;
        this.getDialog("").frozen = data.state == "connected" ? "" : data.state;
        this.notice('Connection state changed to "' + msg);
        break;
      case "frozen":
        this.getDialog("").frozen = data.frozen;
        this.user.ensureDialog(data);
        break;
      case "join":
      case "part":
        this.dialogs().forEach(function(d) { d.participant(data); });
        break;
      case "me":
        if (this.me.nick != data.nick) this.notice('You changed nick to ' + data.nick + '.');
        this.me.nick = data.nick;
        break;
      case "mode":
      case "nick_change":
      case "quit":
        this.dialogs().forEach(function(d) {
          data.dialog_id = d.dialog_id;
          d.participant(data);
        });
        break;
      case "topic":
        this.user.ensureDialog(data);
        break;
    }
  };
})();
