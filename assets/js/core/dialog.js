(function() {
  Convos.Dialog = function(attrs) {
    var self = this;

    EventEmitter(this);
    this.active = undefined;
    this.connection_id = attrs.connection_id;
    this.dialog_id = attrs.dialog_id;
    this.frozen = attrs.frozen || "";
    this.is_private = attrs.is_private || true;
    this.lastActive = 0;
    this.lastRead = attrs.last_read ? Date.fromAPI(attrs.last_read) : new Date();
    this.messages = [];
    this.name = attrs.name || attrs.dialog_id.toLowerCase() || "";
    this.participants = {};
    this.reset = true;
    this.topic = attrs.topic || "";
    this.unread = attrs.unread || 0;
    this.user = attrs.user || new Convos.User({});

    if (attrs.last_active) {
      this.lastActive = Date.fromAPI(attrs.last_active).valueOf();
    }
  };

  var proto = Convos.Dialog.prototype;
  var protectedKeys = ["connection_id", "dialog_id", "name", "participants", "user"];

  proto.addMessage = function(msg, args) {
    if (!args) args = {};
    if (!args.method) args.method = "push";
    var prev = args.method == "unshift" ? this.messages[0] : this.prevMessage;
    msg.richMessage = null;

    if (!msg.from) msg.from = "convosbot";
    if (!msg.type) msg.type = "notice";
    if (!msg.ts) msg.ts = new Date();
    if (typeof msg.ts == "string") msg.ts = Date.fromAPI(msg.ts);
    if (!prev) prev = {from: "", ts: msg.ts};

    if (args.method == "push") {
      this.prevMessage = msg;

      if (this.lastRead < msg.ts && !args.disableUnread) {
        this._increaseUnread(msg);
      }
      if (msg.highlight && !args.disableNotifications && !this.is_private) {
        this.user.unread++;
        this.user.notifications.unshift(msg);
        Notification.simple(msg.from, msg.message);
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

  // Create a href for <a> tag
  proto.href = function() {
    var path = Array.prototype.slice.call(arguments);
    if (!this.connection()) return "#chat/convos-local/convosbot";
    return ["#chat", this.connection_id, this.dialog_id].concat(path).join("/");
  };

  proto.icon = function() {
    return !this.dialog_id ? "device_hub" : this.is_private ? "person" : "group";
  };

  proto.load = function(args, cb) {
    var self = this;
    var method = this.dialog_id ? "dialogMessages" : "connectionMessages";

    if (this.messages.length && this.messages[0].loading) return;
    if (DEBUG.info) console.log("[load:" + this.dialog_id + "] " + JSON.stringify(args)); // TODO

    if (args.historic && this.messages.length > 0) {
      delete args.historic;
      args.before = this.messages[0].ts.toISOString();
    }

    args.connection_id = this.connection_id;
    args.dialog_id = this.dialog_id;

    this.addMessage(
      {loading: true, message: "Loading messages..."},
      {method: args.before ? "unshift" : "push"}
    );

    Convos.api[method](args, function(err, xhr) {
      if (self.reset) self.messages = [];
      self._processMessages(err, xhr.body.messages).reverse().forEach(function(msg) {
        self.addMessage(msg, {method: "unshift", disableNotifications: true, disableUnread: true});
      });
      if (cb) cb(err, xhr.body);
      self.reset = false;
    });
  };

  proto.participant = function(data) {
    if (this.dialog_id != data.dialog_id) return;
    if (!data.nick) data.nick = data.new_nick || data.name;

    switch (data.type) {
      case "join":
        Vue.set(this.participants, data.nick, {name: data.nick, seen: new Date()});
        this.addMessage({message: data.nick + " joined.", from: this.connection_id});
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
        this.addMessage({message: data.old_nick + " changed nick to " + data.nick + ".", from: this.connection_id});
        break;
      default: // part
        if (!this.participants[data.nick]) return;
        var message = data.nick + " parted.";
        Vue.delete(this.participants, data.nick);
        if (data.kicker) message = data.nick + " was kicked by " + data.kicker + ".";
        if (data.message) message += " Reason: " + data.message;
        this.addMessage({message: message, from: this.connection_id});
    }
  };

  proto.setLastRead = function() {
    this.unread = 0;
    Convos.api[this.dialog_id ? "setDialogLastRead" : "setConnectionLastRead"](
      {
        connection_id: this.connection_id,
        dialog_id: this.dialog_id
      }, function(err, xhr) {
        if (err) return console.log("[setDialogLastRead:" + self.dialog_id + "] " + JSON.stringify(err)); // TODO
        self.lastRead = Date.fromAPI(xhr.body.last_read);
      }
    );
  };

  proto.update = function(attrs) {
    var loadMaybe = attrs.hasOwnProperty("active") || attrs.hasOwnProperty("frozen");

    if (attrs.hasOwnProperty("active") && this.active && !attrs.active) this.setLastRead();
    if (attrs.hasOwnProperty("frozen") && this.frozen && !attrs.frozen) this.reset = true;

    Object.keys(attrs).forEach(function(n) {
      if (this.hasOwnProperty(n) && protectedKeys.indexOf(n) == -1) this[n] = attrs[n];
    }.bind(this));

    if (this.reset && this.active) {
      this.load({});
    }

    if (loadMaybe && !this.frozen && this.active) {
      if (!this.is_private) this.connection().send("/names", this, this._setParticipants.bind(this));
      if (this.is_private && this.dialog_id) this.connection().send("/whois " + this.name, this);
    }

    if (this.is_private) {
      [this.name, this.connection().nick()].forEach(function(n) {
        this.participants[n] = {name: n, seen: new Date()};
      }.bind(this));
    }

    return this;
  };

  proto._increaseUnread = function(msg) {
    if (this == this.user.activeDialog()) {
      return;
    }
    else if (this.is_private || msg.type.match(/action|private/)) {
      this.lastActive = msg.ts.valueOf();
      this.unread++;
    }
  };

  proto._processMessages = function(err, messages) {
    var frozen = this.frozen.ucFirst();

    if (err) {
      messages = [{message: err[0].message || "Unknown error.", type: "error"}];
    }
    else if (frozen.match(/password/i)) {
      this.addMessage({type: "password"});
    }
    else if (frozen) {
      messages.push({message: this.dialog_id ? "You are not part of this dialog. " + frozen : frozen, type: "error"});
    }
    else if (!messages.length && this.messages.length <= 1) {
      messages.push({message: this.is_private ? "What do you want to say to " + this.name + "?" : "You have joined " + this.name + ", but no one has said anything as long as you have been here."});
    }

    if (messages.length) {
      this.messages.shift(); // remove "Loading messages...";
    }
    else if (this.messages.length) {
      this.messages[0].message = "End of history.";
    }

    if (Convos.settings.notifications == "default") {
      messages.push({type: "enable-notifications"});
    }

    return messages;
  };

  proto._setParticipants = function(msg) {
    if (msg.errors) return this.addMessage({type: "error", message: msg.errors[0].message});
    this.participants = {};
    msg.participants.forEach(function(p) {
      p.seen = new Date();
      this.participants[p.name] = p;
    }.bind(this));
  };
})();
