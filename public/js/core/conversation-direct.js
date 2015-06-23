(function(window) {
  Convos.ConversationDirect = function(attrs) {
    if (attrs) this.save(attrs);
    riot.observable(this);
    this._method = 'httpCachedGet';
  };

  var proto = Convos.ConversationDirect.prototype;

  // Define attributes
  mixin.base(proto, {
    icon: function() { return 'person'; },
    id: function() { return ''; },
    name: function() { return ''; },
    path: function() { return ''; },
    topic: function() { return ''; },
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
