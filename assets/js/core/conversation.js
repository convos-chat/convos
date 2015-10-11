(function(window) {
  Convos.ConversationRoom = function(attrs) {
    if (attrs) this.update(attrs);
    this._api = Convos.api;
    riot.observable(this);
  };

  var proto = Convos.ConversationRoom.prototype;

  // Define attributes
  mixin.base(proto, {
    connection: function() { throw 'connection() cannot be built'; },
    frozen: function() { return '' },
    icon: function() { return 'group' },
    id: function() { return '' },
    name: function() { return '' },
    path: function() { return '' },
    topic: function() { return '' },
  });

  // Send a message to a room
  proto.send = function(message, cb) {
    var self = this;
    this._api.sendToConversation(
      {body: {message: message}, connection_name: this.connection().name(), conversation_id: this.name()},
      function(err, xhr) { cb.call(self, err); }
    );
    return this;
  };
})(window);
