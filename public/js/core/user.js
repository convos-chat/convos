(function(window) {
  // user = Object.create(Convos.User);
  var User = {_conversations: {}, _connections: {}, _method: 'httpCachedGet'};

  mixin.http(User);

  // Define attributes
  mixin.base(User, {
    avatar: [function() {return ''}, false],
    email:  [function() {return ''}, false]
  });

  // Make the next http method fetch fresh data from server
  User.fresh = function() { this._method = 'httpGet'; return this; };

  // Get a single Convos.Connection object from client side
  User.connection = function(type, name, attrs) {
    if (!type && typeof attrs == 'object') {
      var path = attrs.path.split('/'); // /superman@example.com/IRC/localhost
      type = path[2];
      name = path[3];
    }
    if (!this._connections[type]) this._connections[type] = {};
    if (!attrs) return this._connections[type][name];
    var connection = this._connections[type][name] || Object.create(Convos.Connection);
    attrs.name = name;
    attrs.type = type;
    return this._connections[type][name] = connection.save(attrs);
  };

  // Get a list of Convos.Connection objects from backend
  // Use User.fresh().connections(function() { ... }) to get fresh data from server
  User.connections = function(cb) {
    this[this._method](apiUrl('/connections'), {}, function(err, xhr) {
      var connections = [];
      if (!err) xhr.responseJSON.forEach(function(attrs) { connections.push(this.connection(false, false, attrs)); }.bind(this));
      cb.call(this, err, connections);
    });
    return this.tap('_method', 'httpCachedGet');
  };

  // Get a list of Convos.Conversation objects from backend
  // Use User.fresh().conversations(function() { ... }) to get fresh data from server
  User.conversations = function(cb) {
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
  // Use User.fresh().load(function() { ... }) to get fresh data from server
  User.load = function(cb) {
    this[this._method](apiUrl('/user'), {}, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.avatar(xhr.responseJSON.avatar);
      this.email(xhr.responseJSON.email);
      cb.call(this, '');
    });
    return this.tap('_method', 'httpCachedGet');
  };

  // Update convos user interface
  User.render = function(riotTag) {
    if (riotTag) riotTag.update();
    $('.tooltipped').each(function() {
      var $self = $(this);
      $self.attr('data-tooltip', $self.attr('title') || $self.attr('placeholder')).removeAttr('title');
    }).filter('[data-tooltip]').tooltip();
    Materialize.updateTextFields();
    $('select').material_select();
  };

  // Write user settings to server
  User.save = function(data, cb) {
    if (!cb) {
      if (typeof data.avatar != 'undefined') this.avatar(data.avatar);
      if (typeof data.email  != 'undefined') this.email(data.email);
      return this;
    }

    this.httpPost(apiUrl('/user'), data, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.save(data);
      cb.call(this, err);
    });
  };

  (window['Convos'] = window['Convos'] || {})['User'] = User;
})(window);
