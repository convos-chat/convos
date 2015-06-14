(function(window) {
  Convos.User = function(attrs) {
    if (attrs) this.save(attrs);
    riot.observable(this);
    this._conversations = {};
    this._connections = {};
    this._method = 'httpCachedGet';
  };

  var proto = Convos.User.prototype;

  // Define attributes
  mixin.base(proto, {
    avatar: function() { return ''; },
    email: function() { return ''; }
  });

  mixin.http(proto);

  // Make the next http method fetch fresh data from server
  proto.fresh = function() { this._method = 'httpGet'; return this; };

  // Get a single Convos.Connection object from client side
  proto.connection = function(type, name, attrs) {
    if (!type && typeof attrs == 'object') {
      var path = attrs.path.split('/'); // /superman@example.com/IRC/localhost
      type = path[2];
      name = path[3];
    }
    if (!this._connections[type]) this._connections[type] = {};
    if (!attrs) return this._connections[type][name];
    return this._connections[type][name] = new Convos.Connection(attrs).name(name).type(type);
  };

  // Get a list of Convos.Connection objects from backend
  // Use user.fresh().connections(function() { ... }) to get fresh data from server
  proto.connections = function(cb) {
    this[this._method](apiUrl('/connections'), {}, function(err, xhr) {
      var connections = [];
      if (!err) xhr.responseJSON.forEach(function(attrs) { connections.push(this.connection(false, false, attrs)); }.bind(this));
      cb.call(this, err, connections);
    });
    return this.tap('_method', 'httpCachedGet');
  };

  // Get a list of Convos.Conversation objects from backend
  // Use user.fresh().conversations(function() { ... }) to get fresh data from server
  proto.conversations = function(cb) {
    this[this._method](apiUrl('/conversations'), {}, function(err, xhr) {
      if (!err) {
        xhr.responseJSON.forEach(function(r) {
          var path = r.path.split('/'); // /superman@example.com/IRC/localhost/#convos
          var connection = this.connection(path[2], path[3]);
          connection.conversation(path[4], r);
        }.bind(this));
      }
      cb.call(this, err, $.map(this._conversations, function(v, k) { return v; }));
    });
    return this.tap('_method', 'httpCachedGet');
  };

  // Get user settings from server
  // Use user.fresh().load(function() { ... }) to get fresh data from server
  proto.load = function(cb) {
    this[this._method](apiUrl('/user'), {}, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.save(xhr.responseJSON);
      cb.call(this, '');
    });
    return this.tap('_method', 'httpCachedGet');
  };

  // Update convos user interface
  proto.render = function(riotTag) {
    if (riotTag) riotTag.update();
    $('.tooltipped').each(function() {
      var $self = $(this);
      $self.attr('data-tooltip', $self.attr('title') || $self.attr('placeholder')).removeAttr('title');
    }).filter('[data-tooltip]').tooltip();
    Materialize.updateTextFields();
    $('select').material_select();
  };

  // Write user settings to server
  proto.save = function(attrs, cb) {
    if (!cb) return Object.keys(attrs).forEach(function(k) { if (typeof this[k] == 'function') this[k](attrs[k]); }.bind(this));
    return this.httpPost(apiUrl('/user'), attrs, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.save(data);
      cb.call(this, err);
    });
  };
})(window);
