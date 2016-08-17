(function() {
  Convos.Dialog = function(attrs) {
    this.frozen        = "";
    this.id            = "";
    this.messages      = [];
    this.name          = "";
    this.participants  = {};
    this.unread        = 0;
    this.topic         = "";
    this._api          = Convos.api;
    this._participants = {};

    EventEmitter(this);
    if (attrs) this.update(attrs);
    this.once("visible", this._initialize);
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
    if (typeof msg.ts == "string") msg.ts = new Date(msg.ts);
    if (!prev) prev = {from: "", ts: msg.ts};

    if (args.method == "push") {
      this.prevMessage = msg;
      if (msg.type.match(/action|private/) && this != this.user.getActiveDialog()) this.unread++;
      if (msg.highlight && !args.disableNotifications) {
        Notification.simple(msg.from, msg.message);
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

    this._addParticipant(msg.from, {seen: msg.ts});
    this.messages[args.method](msg);
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
    this._api.messagesByDialog(
      {
        before: this.messages[1].ts,
        connection_id: this.connection_id,
        dialog_id: this.id
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
      this._participants[data.nick] = {};
      this.addMessage({message: data.nick + " joined.", from: this.connection.id, type: "notice"});
    }
    else if (data.type == "nick_change") {
      delete this._participants[data.old_nick];
      this._participants[data.new_nick] = {};
      this.addMessage({message: data.old_nick + " changed nick to " + data.new_nick + ".", from: this.connection.id, type: "notice"});
    }
    else if(this._participants[data.nick]) { // part
      delete this._participants[data.nick];
      this.addMessage({message: data.nick + " parted.", from: this.connection.id, type: "notice"});
    }
  };

  proto.refreshParticipants = function(cb) {
    var self = this;
    Convos.api.participantsInDialog(
      {
        connection_id: this.connection_id,
        dialog_id:     this.id
      }, function(err, xhr) {
        Object.keys(self.participants).forEach(function(k) { self.participants[k].online = false; });
        if (!err) {
          var participants = self._participants = {};
          xhr.body.participants.forEach(function(p) {
            participants[p.name] = p;
            p.online = true;
            self._addParticipant(p.name, p);
          });
        }
        return cb.call(self, err);
      }
    );
  };

  proto.update = function(attrs) {
    Object.keys(attrs).forEach(function(n) { this[n] = attrs[n]; }.bind(this));
  };

  proto._addParticipant = function(name, data) {
    if (this.connection() && name == this.connection().nick()) return;
    var participants = this.participants;
    if (!participants[name]) participants[name] = {name: name, seen: 0};
    Object.keys(data).forEach(function(k) { participants[name][k] = data[k]; });
  };

  proto._endOfHistory = function() {
    if (this.messages[0].loading) {
      this.messages[0].message = "End of history.";
    }
    else {
      this.addMessage({loading: true, message: "End of history", type: "notice"}, {method: "unshift"});
    }
  };

  // Called when this dialog is visible in gui the first time
  proto._initialize = function() {
    if (this.messages.length >= 60) return;
    var self = this;
    self.refreshParticipants(function() {});
    self._api.messagesByDialog(
      {
        connection_id: self.connection_id,
        dialog_id:     self.id
      }, function(err, xhr) {
        if (err) return self.emit("error", err);
        xhr.body.messages.forEach(function(msg) { self.addMessage(msg, {method: "push", disableNotifications: true}); });

        if (!self.messages.length) {
          self.addMessage("You have joined " + self.name + ", but no one has said anything as long as you have been here.");
        }
        if (self.frozen) {
          self.addMessage("You are not part of this channel. " + self.frozen);
        }
        if (Convos.settings.notifications == "default") {
          self.addMessage({type: "enable-notifications"});
        }

        if (xhr.body.end) self._endOfHistory();
        self.emit("initialized", {gotoBottom: true});
      }
    );
  };
})();
