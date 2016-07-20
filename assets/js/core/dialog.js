(function() {
  Convos.Dialog = function(attrs) {
    this.frozen        = "";
    this.id            = "";
    this.messages      = [];
    this.name          = "";
    this.participants  = {};
    this.topic         = "";
    this._active       = false;
    this._api          = Convos.api;
    this._participants = {};

    EventEmitter(this);
    this.on("message", this.addMessage);
    this.on("state", this._onState);
    this.once("show", this._load);

    if (attrs) this.update(attrs);
    this.active(localStorage.getItem("activeDialog") == this.href());
  };

  var proto = Convos.Dialog.prototype;

  proto.active = function(bool) {
    if (typeof bool != "boolean") return this._active;
    this._active = bool;
    if (bool) {
      localStorage.setItem("activeDialog", this.href());
      this.emit("show");
    }
    return this;
  };

  proto.addMessage = function(msg, method) {
    if (typeof msg == "string") msg = {message: msg};
    if (!method) method = "push";
    var prev = method == "unshift" ? this.messages[0] : this.prevMessage;
    msg.classNames = [msg.type];

    if (!msg.from) {
      msg.from = "convosbot";
    }
    if (!msg.ts) {
      msg.ts = new Date();
    }
    if (typeof msg.ts == "string") {
      msg.ts = new Date(msg.ts);
    }
    if (msg.highlight) {
      msg.classNames.push("highlight");
      this.connection.user.notifications.unshift(msg);
    }
    if (!prev) {
      prev = {from: msg.from, ts: msg.ts};
    }
    if (prev && prev.ts.getDate() != msg.ts.getDate()) {
      this.messages[method]({
        classNames: ["day-changed"],
        message:    "Day changed",
        prev:       prev
      });
    }

    if (method == "unshift") {
      prev.prev = msg;
      msg.prev = prev;
    }
    else {
      msg.prev = prev;
    }

    if (method == "push") this.prevMessage = msg;
    this._addParticipant(msg.from, {seen: msg.ts});
    this.messages[method](msg);
  };

  // Create a href for <a> tag
  proto.href = function() {
    var path = Array.prototype.slice.call(arguments);
    if (!this.connection) return "#chat/convos-local/convos";
    return ["#chat", this.connection.id, this.name].concat(path).join("/");
  };

  proto.icon = function() {
    return this.is_private ? "person" : "group";
  };

  proto.notice = function(message) {
    this.emit("message", {
      from:    this.connection.id,
      message: message,
      type:    "notice"
    });
  };

  proto.refreshParticipants = function(cb) {
    var self = this;
    Convos.api.participantsInDialog(
      {
        connection_id: this.connection.id,
        dialog_id:     this.id
      }, function(err, xhr) {
        Object.keys(self.participants).forEach(function(k) { self.participants[k].online = false; });
        if (!err) {
          xhr.body.participants.forEach(function(p) {
            p.online = true;
            self._addParticipant(p.name, p);
          });
        }
        return cb.call(self, err);
      }
    );
  };

  proto.previousMessages = function(args) {
    if (!this.connection) return;
    if (!this.messages.length) return;
    if (this._loadingMessages) return;
    var self = this;
    this._loadingMessages = true;
    this._api.messagesByDialog(
      {
        before: this.messages[0].ts,
        connection_id: this.connection.id,
        dialog_id: this.id
      },
      function(err, xhr) {
        self._loadingMessages = false;
        if (err) return self.emit("error", err);
        if (!xhr.body.messages.length) self._loadingMessages = true; // nothing more to load
        xhr.body.messages.reverse().forEach(function(msg) { self.addMessage(msg, "unshift"); });
      }
    );
  };

  proto.update = function(attrs) {
    Object.keys(attrs).forEach(function(n) { this[n] = attrs[n]; }.bind(this));
  };

  proto._addParticipant = function(name, data) {
    if (this.connection && name == this.connection.nick()) return;
    var participants = this.participants;
    if (!participants[name]) participants[name] = {name: name, seen: 0};
    Object.keys(data).forEach(function(k) { participants[name][k] = data[k]; });
  };

  proto._convosMessages = function() {
    [
      "Please wait for connections and dialogs to be loaded...",
      "Is this your first time here?",
      'To add a connection, select the "Add connection" item in the right side menu, or "Join dialog" to chat with someone.',
    ].forEach(function(m) { this.emit("message", {message: m}); }.bind(this));
  };

  // Called when this dialog is visible in gui the first time
  proto._load = function() {
    if (!this.connection) return this._convosMessages();
    if (this.messages.length >= 60) return;
    var self = this;
    self.refreshParticipants(function() {});
    self._api.messagesByDialog(
      {
        connection_id: self.connection.id,
        dialog_id:     self.id
      }, function(err, xhr) {
        if (err) return self.emit("error", err);
        xhr.body.messages.forEach(function(msg) { self.addMessage(msg); });

        if (!self.messages.length) {
          self.addMessage("You have joined " + self.name + ", but no one has said anything as long as you have been here.");
        }
        if (self.frozen) {
          self.addMessage("You are not part of this channel. " + self.frozen);
        }
        else if (self.topic) {
          self.addMessage("The topic is: " + self.topic.replace(/"/g, ""));
        }

        self.emit("ready");
      }
    );
  };

  proto._onState = function(data) {
    switch (data.type) {
      case "frozen":
        this.frozen = data.frozen;
        break;
      case "join":
        this._participants[data.nick] = {};
        this.notice(data.nick + " joined.");
        break;
      case "nick_change":
        if (this._participants[data.old_nick]) {
          delete this._participants[data.old_nick];
          this._participants[data.new_nick] = {};
          this.notice(data.old_nick + " changed nick to " + data.new_nick + ".");
        }
        break;
      case "part":
        if (this._participants[data.nick]) {
          delete this._participants[data.nick];
          if (!data.message)
            data.message = data.kicker ? "Kicked." : "Bye.";
          this.notice(data.nick + " left. " + data.message);
        }
        break;
      default:
        console.log(data);
    }
  };
})();
