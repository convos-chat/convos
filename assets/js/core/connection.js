(function(window) {
  Convos.Connection = function(attrs) {
    this._method = 'httpCachedGet';
    this._state = 'disconnected';
    riot.observable(this);
    if (attrs) this.update(attrs);
  };

  var proto = Convos.Connection.prototype;

  // Define attributes
  mixin.base(proto, {
    name: function() { return ''; },
    url: function() { return new riot.Url(); },
    user: function() { return false; }
  });

  mixin.http(proto);

  // Join a room or create a private conversation on the server
  proto.joinConversation = function(name, cb) {
    this.httpPost(apiUrl(['connection', this.protocol(), this.name(), 'conversation', name]), {}, function(err, xhr) {
      if (!err) this.user().conversation(false, xhr.responseJSON);
      cb.call(this, err, xhr.responseJSON);
    });
  };

  // Get connection settings from server
  // Use connection.fresh().load(function() { ... }) to get fresh data from server
  proto.load = function(cb) {
    this[this._method](apiUrl(['connection', this.protocol(), this.name()]), {}, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.update(xhr.responseJSON);
      cb.call(this, '');
    });
    return this.tap('_method', 'httpCachedGet');
  };

  proto.protocol = function() {
    var url = this.url();
    var r = url.scheme.apply(url, arguments);
    return r == url ? this : r;
  };

  // Get list of available rooms on server
  proto.rooms = function(cb) {
    this[this._method](apiUrl(['connection', this.protocol(), this.name(), 'rooms']), {}, function(err, xhr) {
      if (err) return cb.call(this, err, []);
      cb.call(this, err, $.map(xhr.responseJSON.rooms, function(attrs) { return new Convos.ConversationRoom(attrs); }));
    });
  };

  // Write connection settings to server
  proto.save = function(cb) {
    var attrs = {url: this.url().toString()}; // It is currently not possible to specify "name"
    if (this.name()) {
      return this.httpPost(apiUrl(['connection', this.protocol(), this.name()]), attrs, function(err, xhr) {
        if (err) return cb.call(this, err);
        this.update(xhr.responseJSON);
        cb.call(this, err);
      });
    }
    else {
      return this.httpPost(apiUrl('connections'), attrs, function(err, xhr) {
        if (err) return cb.call(this, err);
        this.update(xhr.responseJSON);
        cb.call(this, err);
      });
    }
  };

  // override base.update() to make sure we don't mess up url()
  var update = proto.update;
  proto.update = function(attrs) {
    var url = this.url();
    update.call(this, attrs);
    if (attrs.state) this._state = attrs.state;
    if (attrs.url && typeof attrs.url == 'string') url.parse(attrs.url);
    return this.url(url);
  };

  // Change state to "connected" or "disconnected"
  // Can also be used to retrieve state: "connected", "disconnected" or "connecting"
  proto.state = function(state, cb) {
    if (!cb) return this._state;
    throw 'TODO';
  };
})(window);
