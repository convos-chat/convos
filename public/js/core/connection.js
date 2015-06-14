(function(window) {
  // connection = Object.create(Convos.Connection);
  var Connection = {_conversations: {}, _method: 'httpCachedGet', state: 'disconnected'};

  mixin.http(Connection);

  // Define attributes
  mixin.base(Connection, {
    name: [function() {return ''}, false],
    type: [function() {return ''}, false],
    url: [function() {return ''}, false]
  });

  // Get list of available rooms on server
  Connection.allRooms = function(cb) {
    this[this._method](apiUrl(['connection', this.name(), 'rooms']), {}, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.save(data);
      cb.call(this, err);
    });
  };

  // Get connection settings from server
  // Use Connection.fresh().load(function() { ... }) to get fresh data from server
  Connection.load = function(cb) {
    this[this._method](apiUrl('/connection'), {}, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.avatar(xhr.responseJSON.avatar);
      this.email(xhr.responseJSON.email);
      cb.call(this, '');
    });
    return this.tap('_method', 'httpCachedGet');
  };

  // Write connection settings to server
  Connection.save = function(data, cb) {
    if (!cb) {
      if (typeof data.name != 'undefined') this.name(data.name);
      if (typeof data.state != 'undefined') this.state = data.state;
      if (typeof data.type != 'undefined') this.type(data.type);
      if (typeof data.url != 'undefined') this.url(data.url);
      return this;
    }

    this.httpPost(apiUrl(['connection', this.name()]), data, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.save(data);
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
  Connection.state = function(state, cb) {
    if (!cb) return this.state;
    throw 'TODO';
  };

  (window['Convos'] = window['Convos'] || {})['Connection'] = Connection;
})(window);
