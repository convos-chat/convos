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
    type: function() { return ''; },
    url: function() { return ''; }
  });

  mixin.http(proto);

  // Get list of available rooms on server
  proto.rooms = function(cb) {
    this[this._method](apiUrl(['connection', this.type(), this.name(), 'rooms']), {}, function(err, xhr) {
      if (err) return cb.call(this, err, []);
      cb.call(this, err, $.map(xhr.responseJSON, function(attrs) { return new Convos.Room(attrs); }));
    });
  };

  // Get connection settings from server
  // Use connection.fresh().load(function() { ... }) to get fresh data from server
  proto.load = function(cb) {
    this[this._method](apiUrl('/connection'), {}, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.avatar(xhr.responseJSON.avatar);
      this.email(xhr.responseJSON.email);
      cb.call(this, '');
    });
    return this.tap('_method', 'httpCachedGet');
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

  // Send a message to a room or person on server
  Connection.send = function(message, cb) {
    this.httpPost(apiUrl(['connection', this.name(), 'message']), {message: message}, function(err, xhr) {
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
