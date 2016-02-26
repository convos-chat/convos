(function(window) {
  Convos.Dialogue = function(attrs) {
    if (attrs) this.update(attrs);
    this._api = Convos.api;
    riot.observable(this);
    this.on('show', this._on_show);
  };

  var proto = Convos.Dialogue.prototype;

  // Define attributes
  mixin.base(proto, {
    connection: function() { throw 'connection() cannot be built'; },
    frozen: function() { return '' },
    icon: function() { return 'group' },
    id: function() { return '' },
    messages: function() { return []; },
    name: function() { return 'Convos' },
    topic: function() { return '' },
  });

  proto.addMessage = function(message) {
    if (!message.from) message.from = 'Convos';
    if (!message.ts) message.ts = new Date();
    if (typeof message.ts == 'object') message.ts = new Date(message.ts);
    this.messages().push(message);
    riot.update();
  };

  // Create a href for <a> tag
  proto.href = function(action) {
    return ['#dialogue', this.connection().id(), this.name(), action].join('/');
  };

  // Send a message to a room
  proto.send = function(command, cb) {
    var self = this;
    this._api.sendToDialogue(
      {
        body: {command: command},
        connection_id: this.connection().id(),
        dialogue_id: this.name()
      },
      function(err, xhr) { cb.call(self, err); }
    );
    return this;
  };

  // Called when this dialogue is visible in gui
  proto._on_show = function() {
    if (this.messages().length < 60) {
      this._api.messagesByDialogue(
        { connection_id: this.connection().id(), dialogue_id: this.name() },
        function(err, xhr) {
          if (err) return console.log(err);
          this.messages(xhr.body.messages);
          riot.update();
        }.bind(this)
      );
    }
  };
})(window);
