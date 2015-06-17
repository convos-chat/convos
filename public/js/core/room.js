(function(window) {
  Convos.Room = function(attrs) {
    if (attrs) this.save(attrs);
    riot.observable(this);
    this._method = 'httpCachedGet';
  };

  var proto = Convos.Room.prototype;

  // Define attributes
  mixin.base(proto, {
    frozen: function() { return '' },
    icon: function() { return 'mdi-social-group' }, // mdi-social-person
    id: function() { return '' },
    name: function() { return '' },
    path: function() { return '' },
    topic: function() { return '' },
  });

  mixin.http(proto);

  // Send a message to a room
  proto.send = function(message, cb) {
    path = this.path().split('/');
    this.httpPost(apiUrl(['connection', path[2], path[3], 'conversation', path[4], 'message']), {message: message}, function(err, xhr) {
      cb.call(this, err);
    });
  };

  proto.url = function() {
    return this.path().replace(/^\/[^\/]*\//, '#chat/');
  };
})(window);
