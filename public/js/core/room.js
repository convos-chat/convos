(function(window) {
  Convos.Room = function(attrs) {
    if (attrs) this.save(attrs);
    riot.observable(this);
    this._method = 'httpCachedGet';
  };

  var proto = Convos.Room.prototype;

  // Define attributes
  mixin.base(proto, {
    frozen: [function() {return ''}, false],
    id: [function() {return ''}, false],
    name: [function() {return ''}, false],
    topic: [function() {return ''}, false]
  });

  mixin.http(proto);

  // Send a message to a room
  proto.send = function(message, cb) {
    this.httpPost(apiUrl(['connection', this.name(), 'message']), {message: message}, function(err, xhr) {
      cb.call(this, err);
    });
  };

  // Set attributes on client side
  proto.save = function(attrs) {
    if (typeof attrs.frozen != 'undefined') this.frozen(attrs.frozen);
    if (typeof attrs.id != 'undefined') this.id = attrs.id;
    if (typeof attrs.name != 'undefined') this.name(attrs.name);
    if (typeof attrs.topic != 'undefined') this.topic(attrs.topic);
    return this;
  };
})(window);
