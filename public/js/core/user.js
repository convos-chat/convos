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

  // Get or create a single Convos.Connection object on client side
  // Get: user.connection(protocol, name)
  // Create/update: user.connection(protocol, name, attrs)
  proto.connection = function(protocol, name, attrs) {
    if (!protocol && typeof attrs == 'object') {
      var path = attrs.path.split('/'); // /superman@example.com/IRC/localhost
      protocol = path[2];
      name = path[3];
    }
    if (!this._connections[protocol]) this._connections[protocol] = {};
    if (!attrs) return this._connections[protocol][name];
    if (this._connections[protocol][name]) return this._connections[protocol][name].save(attrs);
    this._connections[protocol][name] = new Convos.Connection(attrs).name(name).protocol(protocol).user(this);
    this.trigger('connection', this._connections[protocol][name]);
    return this._connections[protocol][name];
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

  // Get or create a single Convos.ConversationXxx object on client side
  // Get: user.conversation(id)
  // Create/update: user.conversation(id, attrs)
  proto.conversation = function(id, attrs) {
    if (!id && typeof attrs == 'object') id = attrs.id;
    if (!attrs) return this._conversations[id];
    if (this._conversations[id]) return this._conversations[id].save(attrs);
    this._conversations[id] = new Convos[attrs.users ? 'ConversationRoom' : 'ConversationDirect'](attrs);
    this.trigger('conversation', this._conversations[id]);
    return this._conversations[id];
  };

  // Get a list of Convos.ConversationXxx objects from backend
  // Use user.fresh().conversations(function() { ... }) to get fresh data from server
  proto.conversations = function(cb) {
    this[this._method](apiUrl('/conversations'), {}, function(err, xhr) {
      if (!err) xhr.responseJSON.forEach(function(c) { this.conversation(false, c); }.bind(this));
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
