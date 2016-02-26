(function(window) {
  Convos.User = function(attrs) {
    if (attrs) this.update(attrs);
    riot.observable(this);
    this._dialogues = {};
    this._connections = {};
    this._api = Convos.api;
    this._listenForEvents();

    var prev = this.email();
    this.on('email', function(value) {
      if (value != prev && value) Convos.ws.open(function() { this.refresh(); }.bind(this));
      prev = value;
    });
  };

  var proto = Convos.User.prototype;

  // Define attributes
  mixin.base(proto, {
    email: function() { return ''; },
    ws: function() { throw 'ws cannot be build'; }
  });

  // Make the next api method fetch fresh data from server
  proto.fresh = function() { this._api.fresh(); return this; };

  // Add, get or update a Convos.Connection object on client side
  // Get:    c = user.connection(id)
  // Create: c = user.connection(attrs)
  proto.connection = function(c) {
    if (typeof c != 'object') return this._connections[c];
    if (!c.DEFLATE) c = new Convos.Connection(c);
    if (this._connections[c.id()]) throw 'Connection already exists.';
    c.user(this);
    this._connections[c.id()] = c;
    this.trigger('connection', c);
    return c;
  };

  proto.connections = function() {
    var c = this._connections;
    return Object.keys(c).map(function(k) { return c[k]; });
  };

  // Get or create a single Convos.Dialogue object on client side
  // Get:    d = user.dialogue(id)
  // Create: d = user.dialogue(attrs)
  proto.dialogue = function(obj) {
    if (typeof obj != 'object') return this._dialogues[obj];
    obj.connection = this._connections[obj.connection_id];
    var d = new Convos.Dialogue(obj);
    if (this._dialogues[d.id()]) throw 'Dialogue already exists.';
    this._dialogues[d.id()] = d;
    this.trigger('dialogue', d);
    return d;
  };

  proto.dialogues = function() {
    var d = this._dialogues;
    return Object.keys(d).map(function(k) { return d[k]; });
  };

  // Get user settings from server
  // Use user.fresh().load(function() { ... }) to get fresh data from server
  proto.load = function(cb) {
    var self = this;
    this._api.getUser({}, function(err, xhr) {
      if (err) return cb.call(self, err);
      self.update(xhr.body);
      cb.call(self, false);
    });
    return this;
  };

  // Log out the user
  proto.logout = function(cb) {
    var self = this;
    this._api.logoutUser({}, function(err, xhr) {
      if (err) return cb.call(self, err);
      self.email('');
      cb.call(self, false);
    });
    return this;
  };

  // Delete a connection on server side and remove it from the user object
  proto.removeConnection = function(connection, cb) {
    var self = this;
    this._api.removeConnection({connection_id: connection.id()}, function(err, xhr) {
      if (err) return cb.call(self, err);
      delete self._connections[connection.id()];
      cb.call(self, '');
    });
    return this;
  };

  // Refresh related data to the user
  proto.refresh = function() {
    var self = this;

    this._api.listConnections({}, function(err, xhr) {
      if (err) return self.trigger('error', err);
      xhr.body.connections.forEach(function(c) { self.connection(c); });
      self._api.listDialogues({}, function(err, xhr) {
        if (err) return self.trigger('error', err);
        xhr.body.dialogues.forEach(function(d) { self.dialogue(d); });
        self.trigger('refreshed');
      });
    });

    return this;
  };

  // Write user settings to server
  proto.save = function(attrs, cb) {
    var self = this;
    if (!cb) return Object.keys(attrs).forEach(function(k) { if (typeof this[k] == 'function') this[k](attrs[k]); }.bind(this));
    this._api.updateUser({body: attrs}, function(err, xhr) {
      if (err) return cb.call(self, err);
      self.update(attrs);
      cb.call(self, err);
    });
    return this;
  };

  proto._listenForEvents = function() {
    this.ws().on('json', function(e) {
      switch (e.type) {
        case 'message':
          var d = this._dialogues[e.object.id];
          if (d) d.addMessage(e.data[0]);
          break;
      }
    }.bind(this));
  };
})(window);
