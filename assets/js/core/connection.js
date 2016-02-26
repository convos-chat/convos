(function(window) {
  Convos.Connection = function(attrs) {
    this._state = 'disconnected';
    this._api = Convos.api;
    riot.observable(this);
    if (attrs) this.update(attrs);
  };

  var proto = Convos.Connection.prototype;

  // Define attributes
  mixin.base(proto, {
    id: function() { return ''; },
    name: function() { return ''; },
    url: function() { return ''; },
    user: function() { throw 'user cannot be built'; }
  });

  // Join a room or create a private dialogue on the server
  proto.joinDialogue = function(name, cb) {
    var self = this;
    this._api.joinDialogue(
      {body: {name: name}, connection_id: this.id()},
      function(err, xhr) {
        if (!err) self.user().dialogue(xhr.body);
        cb.call(self, err, xhr.body);
      }
    );
    return this;
  };

  // Create a href for <a> tag
  proto.href = function(action) {
    return ['#connection', this.protocol(), this.name(), action].join('/');
  };

  // Human readable version of state()
  proto.humanState = function() {
    return this.state().ucFirst();
  }

  // Return protocol (scheme) from url()
  proto.protocol = function() {
    var protocol = this.url().match(/^(\w+):\/\//);
    return protocol ? protocol[1] : 'unknown';
  };

  // Get list of available rooms on server
  proto.rooms = function(cb) {
    var self = this;
    this._api.roomsByConnection(
      {connection_id: this.id()},
      function(err, xhr) {
        if (err) return cb.call(self, err, []);
        cb.call(self, err, $.map(xhr.body.rooms, function(attrs) { return new Convos.Dialogue(attrs); }));
      }
    );
    return this;
  };

  // Write connection settings to server
  proto.save = function(cb) {
    var self = this;
    var attrs = {url: this.url()}; // It is currently not possible to specify "name"

    if (this.id()) {
      this._api.updateConnection(
        {body: attrs, connection_id: this.id()},
        function(err, xhr) {
          if (err) return cb.call(self, err);
          self.update(xhr.body);
          cb.call(self, err);
        }
      );
    }
    else {
      this._api.createConnection({body: attrs}, function(err, xhr) {
        if (err) return cb.call(self, err);
        self.update(xhr.body);
        self.user().connection(self);
        cb.call(self, err);
      });
    }
    return this;
  };

  // override base.update() to make sure we don't mess up url()
  var update = proto.update;
  proto.update = function(attrs) {
    var url = this.url();
    update.call(this, attrs);
    if (attrs.state) this._state = attrs.state;
    if (attrs.url && typeof attrs.url == 'string') this.url(attrs.url);
    return this;
  };

  // Change state to "connected" or "disconnected"
  // Can also be used to retrieve state: "connected", "disconnected" or "connecting"
  proto.state = function(state, cb) {
    if (!cb) return this._state;
    throw 'TODO';
  };
})(window);
