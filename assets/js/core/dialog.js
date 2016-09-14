(function() {
  Convos.Dialog = function(attrs) {
    this.activated    = 0;
    this.active       = false;
    this.dialog_id    = "";
    this.frozen       = "Loading...";
    this.is_private   = true;
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
    if (this.dialog_id != data.dialog_id) return;
    if (!data.nick) data.nick = data.new_nick || data.name;

    switch (data.type) {
      case "join":
        Vue.set(this.participants, data.nick, {name: data.nick, seen: new Date()});
        this.addMessage({message: data.nick + " joined.", from: this.connection_id, type: "notice"});
        break;
      case "maintain":
        if (!this.participants[data.nick]) return;
        this.participants[data.nick].seen = data.ts || new Date();
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

  proto.update = function(attrs) {
    var self = this;
    var frozen = this.frozen;

    Object.keys(attrs).forEach(function(n) { self[n] = attrs[n]; });
    if (attrs.hasOwnProperty("frozen") && attrs.frozen == "" && frozen && !this.is_private) {
      this.user.ws.when("open", function() {
        self.connection().send("/names", self, self._setParticipants.bind(self));
      });
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

  proto._load = function() {
    var self = this;

    Convos.api.messages(
      {
        connection_id: this.connection_id,
        dialog_id: this.dialog_id
      }, function(err, xhr) {
        var messages = xhr.body.messages || [];
        self.messages = []; // clear old messages on ws reconnect
        messages.forEach(function(msg) { self.addMessage(msg, {method: "push", disableNotifications: true}) });
        self._onJoin();
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
    } else if (!this.messages.length) {
      var message = this.is_private ? "What do you want to say to " + this.name + "?" : "You have joined " + this.name + ", but no one has said anything as long as you have been here.";
      this.addMessage({message: message, type: "notice"}, {disableUnread: true});
    }
    if (Convos.settings.notifications == "default") {
      this.addMessage({type: "enable-notifications"});
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
