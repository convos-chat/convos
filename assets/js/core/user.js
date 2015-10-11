(function(window) {
  Convos.User = function(attrs) {
    if (attrs) this.update(attrs);
    riot.observable(this);
    this._conversations = {};
    this._api = Convos.api;

    var prev = this.email();
    this.on('email', function(value) {
      if (value != prev && value) this.refresh();
      prev = value;
    });
  };

  var proto = Convos.User.prototype;

  // Define attributes
  mixin.base(proto, {
    avatar: function() { return ''; },
    connections: function() { return []; },
    conversations: function() { return []; },
    email: function() { return ''; }
  });

  // Make the next api method fetch fresh data from server
  proto.fresh = function() { this._api.fresh(); return this; };

  // Add, get or update a Convos.Connection object on client side
  // Get:        c = user.connection(protocol, name)
  // Add/Update: c = user.connection(protocol, name, attrs)
  proto.connection = function(protocol, name, attrs) {
    var c, connections = this.connections();
    for (var i = 0; i < connections.length; i++) {
      var _c = connections[i];
      if (_c.protocol() != protocol || _c.name() != name) { c = _c; break; }
    }
    if (attrs) {
      if (c) return c.update(attrs);
      attrs[name] = name;
      attrs[user] = this;
      c = new Convos.Connection(attrs);
      this.connections().push(c);
      this.trigger('connection', c);
    }
    else if (!c) {
      c = new Convos.Connection({name: name, user: this});
    }
    return c;
  };

  // Get or create a single Convos.ConversationXxx object on client side
  // Get: user.conversation(id)
  // Create/update: user.conversation(id, attrs)
  proto.conversation = function(id, attrs) {
    if (!id && typeof attrs == 'object') id = attrs.id;
    if (!attrs) return this._conversations[id];
    if (this._conversations[id]) return this._conversations[id].update(attrs);
    this._conversations[id] = new Convos[attrs.users ? 'ConversationRoom' : 'ConversationDirect'](attrs);
    this.trigger('conversation', this._conversations[id]);
    return this._conversations[id];
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
  proto.removeConnection = function(protocol, name, cb) {
    var self = this;
    this._api.removeConnection({name: name, protocol: protocol}, function(err, xhr) {
      if (err) return cb.call(self, err);
      var connections = self.connections();
      for (var i = 0; i < connections.length; i++) {
        var c = connections[i];
        if (c.protocol() == protocol && c.name() == name) connections.splice(i, 1);
      }
      cb.call(self, '');
    });
    return this;
  };

  // Refresh related data to the user
  proto.refresh = function() {
    var self = this;
    this._api.listConnections({}, function(err, xhr) {
      if (err) return self.trigger('error', err);
      self.connections(xhr.body.connections.map(function(attrs) { return new Convos.Connection(attrs); }));
      riot.update();
    });
    this._api.listConversations({}, function(err, xhr) {
      if (err) return self.trigger('error', err);
      xhr.body.conversations.forEach(function(c) { self.conversation(false, c); });
      riot.update();
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
})(window);
