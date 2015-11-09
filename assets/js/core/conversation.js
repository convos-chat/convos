(function(window) {
  Convos.Conversation = function(attrs) {
    if (attrs) this.update(attrs);
    this._api = Convos.api;
    riot.observable(this);
  };

  var proto = Convos.Conversation.prototype;

  // Define attributes
  mixin.base(proto, {
    connection: function() { throw 'connection() cannot be built'; },
    frozen: function() { return '' },
    icon: function() { return 'group' },
    id: function() { return '' },
    name: function() { return '' },
    topic: function() { return '' },
  });

  // Send a message to a room
  proto.send = function(command, cb) {
    var self = this;
    this._api.sendToConversation(
      {
        body: {command: command},
        connection_id: this.connection().id(),
        conversation_id: this.name()
      },
      function(err, xhr) { cb.call(self, err); }
    );
    return this;
  };

  proto.url = function() {
    return [this.connection().id(), this.id()].join('/');
  };
})(window);
