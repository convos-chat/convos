(function(window) {
  Convos.Connection = function(attrs) {
    if (attrs) this.save(attrs);
    riot.observable(this);
    this._method = 'httpCachedGet';
    this.state = 'disconnected';
  };

  var proto = Convos.Connection.prototype;

  // Define attributes
  mixin.base(proto, {
    name: function() { return ''; },
    protocol: function() { return ''; },
    url: function() { return ''; }
  });

  mixin.http(proto);

  // Join a room or create a private conversation on the server
  proto.createConversation = function(name, cb) {
    this.httpPost(
      apiUrl(['connection', this.protocol(), this.name(), 'rooms']),
      {name: name},
      function(err, xhr) { cb.call(this, err); }
    );
  };

  // Get connection settings from server
  // Use connection.fresh().load(function() { ... }) to get fresh data from server
  proto.load = function(cb) {
    this[this._method](apiUrl('/connection'), {}, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.save(xhr.responseJSON);
      cb.call(this, '');
    });
    return this.tap('_method', 'httpCachedGet');
  };

  // Get list of available rooms on server
  proto.rooms = function(cb) {
    this[this._method](apiUrl(['connection', this.protocol(), this.name(), 'rooms']), {}, function(err, xhr) {
      if (err) return cb.call(this, err, []);
      cb.call(this, err, $.map(xhr.responseJSON, function(attrs) { return new Convos.Room(attrs); }));
    });
  };

  // Write connection settings to server
  proto.save = function(attrs, cb) {
    if (!cb) return Object.keys(attrs).forEach(function(k) { if (typeof this[k] == 'function') this[k](attrs[k]); }.bind(this));
    return this.httpPost(apiUrl(['connection', this.name()]), attrs, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.save(attrs);
      cb.call(this, err);
    });
  };

  // Change state to "connected" or "disconnected"
  // Can also be used to retrieve state: "connected", "disconnected" or "connecting"
  proto.state = function(state, cb) {
    if (!cb) return this.state;
    throw 'TODO';
  };
})(window);
