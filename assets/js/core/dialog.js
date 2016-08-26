(function() {
  Convos.Dialog = function(attrs) {
    this.active       = false;
    this.dialog_id    = "";
    this.frozen       = "";
    this.activated    = 0;
    this.messages     = [];
    this.name         = "";
    this.lastRead     = attrs.last_read ? Date.fromAPI(attrs.last_read) : new Date();
    this.participants = {};
    this.unread       = 0;
    this.topic        = "";

    EventEmitter(this);
    if (attrs) this.update(attrs);

    this.on("active", function() {
      this.user.dialogs.forEach(function(d) { if (d.active) d.emit("inactive"); });
      this.active = true;
      this.unread = 0;
      if (!this.activated++) this._load();
    });

    this.on("inactive", function() {
      var self = this;
      this.active = false;
      Convos.api.setDialogLastRead(
        {
          connection_id: this.connection_id,
          dialog_id: this.dialog_id,
        }, function(err, xhr) {
          if (err) return console.log('[setDialogLastRead] ' + JSON.stringify(err)); // TODO
          self.lastRead = Date.fromAPI(xhr.body.last_read);
        }
      );
    });

    this.on("join", this._onJoin);
  };

  var proto = Convos.Dialog.prototype;

  proto.addMessage = function(msg, args) {
    if (!args) args = {};
    if (typeof msg == "string") msg = {message: msg};
    if (!args.method) args.method = "push";
    var prev = args.method == "unshift" ? this.messages[0] : this.prevMessage;

    if (!msg.from) msg.from = "convosbot";
    if (!msg.type) msg.type = "private";
    if (!msg.ts) msg.ts = new Date();
    if (typeof msg.ts == "string") msg.ts = Date.fromAPI(msg.ts);
    if (!prev) prev = {from: "", ts: msg.ts};

    if (args.method == "push") {
      this.prevMessage = msg;

      if (msg.type.match(/action|private/) && this != this.user.getActiveDialog()) {
        if (this.lastRead < msg.ts && !args.disableUnread) {
          this.unread++;
        }
      }
      if (msg.highlight && !args.disableNotifications) {
        Notification.simple(msg.from, msg.message);
        this.user.unread++;
        this.connection().user.notifications.unshift(msg);
      }
      if (prev && prev.ts.getDate() != msg.ts.getDate()) {
        this.messages[args.method]({type: "day-changed", prev: prev, ts: msg.ts});
      }
    }

    if (args.method == "unshift") {
      prev.prev = msg;
      msg.prev = prev;
    }
    else {
      msg.prev = prev;
    }

    this.messages[args.method](msg);
    this.participant({type: "maintain", name: msg.from, seen: msg.ts});
    if (args.method == "push") this.emit("message", msg);
  };

  proto.connection = function() {
    return this.user.getConnection(this.connection_id);
  };

  proto.historicMessages = function(args, cb) {
    if (!this.messages.length) return;
    if (this.messages[0].loading) return;
    var self = this;
    this.addMessage({loading: true, message: "Loading messages...", type: "notice"}, {method: "unshift"});
    Convos.api.messages(
      {
        before: this.messages[1].ts.toISOString(),
        connection_id: this.connection_id,
        dialog_id: this.dialog_id
      },
      function(err, xhr) {
        if (err) return cb(err, null);
        if (xhr.body.messages.length && xhr.body.end) {
          self.messages.shift();
        }
        else {
          self._endOfHistory();
        }
        cb(null, function() {
          xhr.body.messages.reverse().forEach(function(msg) { self.addMessage(msg, {method: "unshift"}); });
        })
      }
    );
  };

  // Create a href for <a> tag
  proto.href = function() {
    var path = Array.prototype.slice.call(arguments);
    if (!this.connection()) return "#chat/convos-local/convosbot";
    return ["#chat", this.connection_id, this.name].concat(path).join("/");
  };

  proto.icon = function() {
    return this.is_private ? "person" : "group";
  };

  proto.participant = function(data) {
    if (data.type == "join") {
      this.participants[data.nick] = {name: data.nick, seen: new Date()};
      this.addMessage({message: data.nick + " joined.", from: this.connection_id, type: "notice"});
    }
    else if (data.type == "nick_change") {
      if (this.participants[data.old_nick]) {
        delete this.participants[data.old_nick];
        this.participants[data.nick] = {name: data.nick, seen: new Date()};
        this.addMessage({message: data.old_nick + " changed nick to " + data.new_nick + ".", from: this.connection_id, type: "notice"});
      }
    }
    else if (data.type == "maintain") {
      if (this.participants[data.nick || data.name]) {
        this.participants[data.nick || data.name].seen = data.ts || new Date();
      }
    }
    else if(this.participants[data.nick]) { // part
      delete this.participants[data.nick];
      this.addMessage({message: data.nick + " parted.", from: this.connection_id, type: "notice"});
    }
  };

  proto.refreshParticipants = function(cb) {
    var self = this;
    Convos.api.participants(
      {
        connection_id: this.connection_id,
        dialog_id: this.dialog_id
      }, function(err, xhr) {
        if (!err) {
          self.participants = {};
          xhr.body.participants.forEach(function(p) {
            self.participants[p.name] = {name: p.name, seen: new Date()};
          });
        }
        return cb.call(self, err);
      }
    );
  };

  proto.update = function(attrs) {
    Object.keys(attrs).forEach(function(n) { this[n] = attrs[n]; }.bind(this));
    return this;
  };

  proto._endOfHistory = function() {
    if (this.messages[0].loading) {
      this.messages[0].message = "End of history.";
    }
    else {
      this.addMessage({loading: true, message: "End of history", type: "notice"}, {method: "unshift"});
    }
  };

  proto._load = function() {
    var self = this;

    this.refreshParticipants(function() {});
    Convos.api.messages(
      {
        connection_id: this.connection_id,
        dialog_id: this.dialog_id
      }, function(err, xhr) {
        if (err) return self.emit("error", err);

        self.messages = []; // clear old messages on ws reconnect
        xhr.body.messages.forEach(function(msg) {
          self.addMessage(msg, {method: "push", disableNotifications: true});
        });

        self.emit("join");
      }
    );
  };

  proto._onJoin = function() {
    if (this.frozen) {
      this.addMessage({
        type: "error",
        message: "You are not part of this channel. " + this.frozen
      }, {
        disableUnread: true
      });
    } else if (this.messages.length) {
      this.addMessage({
        type: "notice",
        message: "You have joined " + this.name + "."
      }, {
        disableUnread: true
      });
    } else {
      this.addMessage("You have joined " + this.name + ", but no one has said anything as long as you have been here.", {
        disableUnread: true
      });
    }
    if (Convos.settings.notifications == "default") {
      this.addMessage({type: "enable-notifications"});
    }
  };
})();
