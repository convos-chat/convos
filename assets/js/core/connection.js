(function(window) {
  Convos.Connection = function(attrs) {
    EventEmitter(this);
    this._state = "disconnected";
    this._api   = Convos.api;
    this.on("me", this._onMe);
    this.on("state", this._onState);
    this.on("message", this._onMessage);
    if (attrs) this.update(attrs);
  };

  var proto = Convos.Connection.prototype;

  proto.highlightMessage = function(msg) {
    var query     = this.url().parseUrl().query;
    var highlight = [];
    if (this.nick()) highlight.push(this.nick());
    if (query.highlight)
      highlight = highlight.concat(query.highlight.split(" "));
    if (!highlight.length) return;
    highlight     = new RegExp("\\b" + highlight.join("|") + "\\b");
    msg.highlight = msg.message.match(highlight) ? true : false;
  };

  // Join a room or create a private dialog on the server
  proto.joinDialog = function(dialogName, cb) {
    var self = this;
    this._api.joinDialog(
      {
        body: {
          name: dialogName
        },
        connection_id: this.id
      }, function(err, xhr) {
        var d;
        if (!err)
          d = self.user.dialog(xhr.body);
        cb.call(self, err, d, xhr.body);
      }
    );
    return this;
  };

  // Create a href for <a> tag
  proto.href = function(action) {
    return ["#connection", this.protocol(), this.name, action].join("/");
  };

  // Human readable version of state()
  proto.humanState = function() {
    return this.state().ucFirst();
  };

  proto.nick = function() {
    this.url.parseUrl().query.nick || "";
  };

  // Return protocol (scheme) from url
  proto.protocol = function() {
    var protocol = this.url.match(/^(\w+):\/\//);
    return protocol ? protocol[1] : "unknown";
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
        self.user.connection(self);
        cb.call(self, err);
      });
    }
    return this;
  };

  proto.update = function(attrs) {
    var self = this;
    Object.keys(attrs).forEach(function(n) {
      self[n] = attrs[n];
    });
    this.emit("updated");
  };

  // Change state to "connected" or "disconnected"
  // Can also be used to retrieve state: "connected", "disconnected" or "queued"
  proto.state = function(state, cb) {
    if (!cb) return this._state;
    throw "TODO";
  };

  proto._onMe = function(data) {
    console.log(data);
    if (data.nick) this.nick(data.nick);
  };

  proto._onMessage = function(data) {
    data.from = this.id;
    data.type = "notice";
    this.user.currentDialog().emit("message", data);
  };

  proto._onState = function(data) {
    this.state(data.state);
    this.user.currentDialog().emit("message", {
      from:    this.id,
      message: data.message + " (" + data.state + ")",
      ts:      data.ts,
      type:    "notice"
    });
  };
})(window);
