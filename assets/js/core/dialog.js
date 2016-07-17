(function() {
  Convos.Dialog = function(attrs) {
    this.frozen        = "";
    this.id            = "";
    this.messages      = [];
    this.name          = "";
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

  proto.addMessage = function(msg) {
    var prev = this.prevMessage || {};
    msg.classNames = [msg.type];

    if (!msg.from)
      msg.from = "convosbot";
    if (!msg.ts)
      msg.ts = new Date();
    if (typeof msg.ts == "string")
      msg.ts = new Date(msg.ts);
    if (!prev.ts)
      prev.ts = msg.ts;

    if (msg.highlight) {
      msg.classNames.push("highlight");
      this.connection.user.notifications.unshift(msg);
    }

    msg.classNames.push(
      msg.message && msg.from == prev.from && msg.ts.epoch() - 300 < prev.ts.epoch()
        ? "same-user" : "changed-user");

    if (prev.ts.getDate() != msg.ts.getDate())
      this.messages.push({
        classNames: ["day-changed"],
        message:    "Day changed"
      });

    this.prevMessage = msg;
    this.messages.push(msg);
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

  proto.participants = function(cb) {
    var self = this;
    Convos.api.participantsInDialog(
      {
        connection_id: this.connection.id,
        dialog_id:     this.id
      }, function(err, xhr) {
        if (!err) {
          var participants = self._participants = {};
          xhr.body.participants.forEach(function(p) {
            participants[p.name] = p;
          });
        }
        return cb.call(self, err, xhr.body.participants);
      }
    );
  };

  proto.update = function(attrs) {
    var self = this;
    Object.keys(attrs).forEach(function(n) {
      self[n] = attrs[n];
    });
  };

  proto._convosMessages = function() {
    [
      "Please wait for connections and dialogs to be loaded...",
      "Is this your first time here?",
      'To add a connection, select the "Add connection" item in the right side menu, or "Join dialog" to chat with someone.',
    ].forEach(function(m) {
      this.emit("message", {
        message: m
      });
    }.bind(this));
  };

  proto._initialMessages = function() {
    var topic = this.topic.replace(/"/g, "") || "";
    this.addMessage({
      message: "You have joined " + this.name + ", but no one has said anything as long as you have been here."
    });
    if (this.frozen) {
      this.addMessage({
        message: "You are not part of this channel. " + this.frozen
      });
    }
  };

  // Called when this dialog is visible in gui the first time
  proto._load = function() {
    if (!this.connection) return this._convosMessages();
    if (this.messages.length >= 60) return;
    var self = this;
    self.participants(function() {});
    self._api.messagesByDialog(
      {
        connection_id: self.connection.id,
        dialog_id:     self.id
      }, function(err, xhr) {
        if (err) return this.emit("error", err);
        xhr.body.messages.forEach(function(msg) {
          self.addMessage(msg);
        });
        if (!self.messages.length) self._initialMessages();
        this.emit("ready");
      }.bind(this)
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
