(function(window) {
  Convos.User = function(attrs) {
    if (attrs) this.update(attrs);
    riot.observable(this);
    this._conversations = {};
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
    avatar: function() { return ''; },
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

  // Get or create a single Convos.ConversationXxx object on client side
  // Get:    c = user.conversation(id)
  // Create: c = user.conversation(attrs)
  proto.conversation = function(obj) {
    if (typeof obj != 'object') return this._conversations[obj];
    obj.connection = this._connections[obj.connection_id];
    var c = new Convos.Conversation(obj);
    if (this._conversations[c.id()]) throw 'Conversation already exists.';
    this._conversations[c.id()] = c;
    this.trigger('conversation', c);
    return c;
  };

  proto.conversations = function() {
    var c = this._conversations;
    return Object.keys(c).map(function(k) { return c[k]; });
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
      self._api.listConversations({}, function(err, xhr) {
        if (err) return self.trigger('error', err);
        xhr.body.conversations.forEach(function(c) { self.conversation(c); });
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
          var c = this._conversations[e.object.id];
          if (c) c.addMessage(e.data[0]);
          break;
      }
    }.bind(this));
  };
})(window);
