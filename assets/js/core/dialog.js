(function() {
  Convos.Dialog = function(attrs) {
    this.activated = 0;
    this.active = undefined;
    this.dialog_id = "";
    this.frozen = "Initializing...";
    this.is_private = true;
    this.messages = [];
    this.name = "";
    this.lastActive = 0;
    this.lastRead = attrs.last_read ? Date.fromAPI(attrs.last_read) : new Date();
    this.participants = {};
    this.unread = 0;
    this.topic = "";

    EventEmitter(this);
    if (attrs) this.update(attrs);

    if (this.last_active) {
      this.lastActive = Date.fromAPI(this.last_active).valueOf();
      delete this.last_active;
    }
  };

  var proto = Convos.Dialog.prototype;

  proto.activate = function() {
    var self = this;

    this.unread = 0;
    this.user.ws.when("open", function() {
      if (self.frozen || !self.dialog_id) return;
      if (!self.is_private) self.connection().send("/names", self, self._setParticipants.bind(self));
      if (self.is_private) self.connection().send("/whois " + self.name, self); // TODO: Add handling of whois response. Set "frozen" if user is offline
    });

    if (this.messages.length) return;
    Convos.api[this.dialog_id ? "dialogMessages" : "connectionMessages"](
      {
        connection_id: this.connection_id,
        dialog_id: this.dialog_id
      }, function(err, xhr) {
        var frozen = self.frozen.ucFirst();
        var messages = xhr.body.messages || [];

        if (err) {
          messages.push({message: err[0].message || "Unknown error.", type: "error"});
        }
        else if (frozen) {
          messages.push({message: self.dialog_id ? "You are not part of this dialog. " + frozen : frozen, type: "error"});
        }
        else if (!messages.length) {
          messages.push({message: self.is_private ? "What do you want to say to " + self.name + "?" : "You have joined " + self.name + ", but no one has said anything as long as you have been here.", type: "notice"});
        }

        if (Convos.settings.notifications == "default") {
          messages.push({type: "enable-notifications"});
        }

        messages.forEach(function(msg) {
          self.addMessage(msg, {disableNotifications: true, disableUnread: true});
        });
      }
    );
  };

  proto.addMessage = function(msg, args) {
    if (!args) args = {};
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
          this.lastActive = msg.ts.valueOf();
          this.unread++;
        }
      }
      if (msg.highlight && !args.disableNotifications) {
        Notification.simple(msg.from, msg.message);
        this.user.unread++;
        this.connection().user.notifications.unshift(msg);
      }
      if (prev && prev.ts.getDate() != msg.ts.getDate()) {
        prev = {type: "day-changed", prev: prev, ts: msg.ts};
        this.messages[args.method](prev);
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
    if (args.type == "participants") this._setParticipants(msg);
    this.emit("message", msg);
  };

  proto.connection = function() {
    return this.user.getConnection(this.connection_id);
  };

  proto.historicMessages = function(args, cb) {
    if (!this.messages.length) return;
    if (this.messages[0].loading) return;

    this.addMessage({loading: true, message: "Loading messages...", type: "notice"}, {method: "unshift"});

    var self = this;
    Convos.api[this.dialog_id ? "dialogMessages" : "connectionMessages"](
      {
        before: this.messages[1].ts.toISOString(),
        connection_id: this.connection_id,
        dialog_id: this.dialog_id
      },
      function(err, xhr) {
        self.messages.shift(); // remove "Loading messages...";
        if (xhr.body.messages) {
          if (!xhr.body.messages.length) self._endOfHistory();
          xhr.body.messages.reverse().forEach(function(msg) { self.addMessage(msg, {method: "unshift"}); });
        }
        cb(err, xhr.body);
      }
    );
  };

  // Create a href for <a> tag
  proto.href = function() {
    var path = Array.prototype.slice.call(arguments);
    if (!this.connection()) return "#chat/convos-local/convosbot";
    return ["#chat", this.connection_id, this.dialog_id].concat(path).join("/");
  };

  proto.icon = function() {
    return !this.dialog_id ? "device_hub" : this.is_private ? "person" : "group";
  };

  proto.participant = function(data) {
    if (this.dialog_id != data.dialog_id) return;
    if (!data.nick) data.nick = data.new_nick || data.name;

    switch (data.type) {
      case "join":
        Vue.set(this.participants, data.nick, {name: data.nick, seen: new Date()});
        this.addMessage({message: data.nick + " joined.", from: this.connection_id, type: "notice"});
        break;
      case "maintain":
        if (!this.participants[data.nick]) return;
        this.participants[data.nick].seen = data.ts || new Date();
        break;
      case "mode":
        if (!this.participants[data.nick]) return;
        this.participants[data.nick].mode = data.mode;
        break;
      case "nick_change":
        if (!this.participants[data.nick]) return;
        Vue.delete(this.participants, data.old_nick);
        Vue.set(this.participants, data.nick, {name: data.nick, seen: new Date()});
        this.addMessage({message: data.old_nick + " changed nick to " + data.nick + ".", from: this.connection_id, type: "notice"});
        break;
      default: // part
        if (!this.participants[data.nick]) return;
        var message = data.nick + " parted.";
        Vue.delete(this.participants, data.nick);
        if (data.kicker) message = data.nick + " was kicked by " + data.kicker + ".";
        if (data.message) message += " Reason: " + data.message;
        this.addMessage({message: message, from: this.connection_id, type: "notice"});
    }
  };

  proto.setLastRead = function() {
    Convos.api[this.dialog_id ? "setDialogLastRead" : "setConnectionLastRead"](
      {
        connection_id: this.connection_id,
        dialog_id: this.dialog_id
      }, function(err, xhr) {
        if (err) return console.log('[setDialogLastRead] ' + JSON.stringify(err)); // TODO
        self.lastRead = Date.fromAPI(xhr.body.last_read);
      }
    );
  };

  proto.update = function(attrs) {
    var self = this;
    var frozen = this.frozen;

    Object.keys(attrs).forEach(function(n) { self[n] = attrs[n]; });

    if (this.is_private) {
      [this.name, this.connection().nick()].forEach(function(n) {
        this.participants[n] = {name: n, seen: new Date()};
      }.bind(this));
    }

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

  proto._setParticipants = function(msg) {
    this.participants = {};
    msg.participants.forEach(function(p) {
      p.seen = new Date();
      this.participants[p.name] = p;
    }.bind(this));
  };
})();
