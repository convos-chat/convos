(function() {
  Convos.Dialog = function(attrs) {
    this.frozen        = "";
    this.id            = "";
    this.messages      = [];
    this.name          = "";
    this.participants  = {};
    this.topic         = "";
    this._api          = Convos.api;
    this._participants = {};

    EventEmitter(this);
    if (attrs) this.update(attrs);
    this.on("message", this.addMessage);
    this.once("visible", this._initialize);
  };

  var proto = Convos.Dialog.prototype;

  proto.addMessage = function(msg, method) {
    if (typeof msg == "string") msg = {message: msg};
    if (!method) method = "push";
    var prev = method == "unshift" ? this.messages[0] : this.prevMessage;

    if (!msg.from) msg.from = "convosbot";
    if (!msg.type) msg.type = "private";
    if (!msg.ts) msg.ts = new Date();
    if (typeof msg.ts == "string") msg.ts = new Date(msg.ts);
    if (msg.highlight) this.connection().user.notifications.unshift(msg);
    if (!prev) prev = {from: "", ts: msg.ts};
    if (prev && prev.ts.getDate() != msg.ts.getDate()) {
      this.messages[method]({type: "day-changed", prev: prev});
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

  proto.connection = function() {
    return this.user.getConnection(this.connection_id);
  };

  proto.historicMessages = function(args) {
    if (!this.messages.length) return;
    if (this._loadingMessages) return;
    var self = this;
    this._loadingMessages = true;
    this._api.messagesByDialog(
      {
        before: this.messages[0].ts,
        connection_id: this.connection_id,
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

  // Create a href for <a> tag
  proto.href = function() {
    var path = Array.prototype.slice.call(arguments);
    if (!this.connection()) return "#chat/convos-local/convosbot";
    return ["#chat", this.connection_id, this.name].concat(path).join("/");
  };

  proto.icon = function() {
    return this.is_private ? "person" : "group";
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
          xhr.body.participants.forEach(function(p) {
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
        xhr.body.messages.forEach(function(msg) { self.addMessage(msg); });

        if (!self.messages.length) {
          self.addMessage("You have joined " + self.name + ", but no one has said anything as long as you have been here.");
        }
        if (self.frozen) {
          self.addMessage("You are not part of this channel. " + self.frozen);
        }

        self.emit("initialized", {gotoBottom: true});
      }
    );
  };
})();
