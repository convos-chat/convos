(function(window) {
  Convos.ConversationDirect = function(attrs) {
    if (attrs) this.update(attrs);
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

  // Returns a path (URL) to the messages resource
  proto.messagesUrl = function() {
    var path = this.path().split('/');
    return apiUrl(['connection', path[2], path[3], 'conversation', path[4], 'messages']);
  };

  // Send a message to a room
  proto.send = function(message, cb) {
    this.httpPost(this.messagesUrl(), {message: message}, function(err, xhr) {
      cb.call(this, err);
    });
  };

  proto.url = function() {
    return this.path().replace(/^\/[^\/]*\//, '#chat/');
  };
})(window);
