(function(window) {
  Convos.Dialog = function(attrs) {
    if (attrs) this.update(attrs);
    this._api = Convos.api;
    riot.observable(this);
    this.on('show', this._onShow);
  };

  var proto = Convos.Dialog.prototype;

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
    if (typeof message.ts == 'string') message.ts = new Date(message.ts);
    this.messages().push(message);
  };

  // Create a href for <a> tag
  proto.href = function(action) {
    return ['#dialog', this.connection().id(), this.name(), action].join('/');
  };

  // Send a message to a dialog
  proto.send = function(command, cb) {
    var self = this;
    this._api.sendToDialog(
      {
        body: {command: command},
        connection_id: this.connection().id(),
        dialog_id: this.name()
      },
      function(err, xhr) { cb.call(self, err); }
    );
    return this;
  };

  proto._initialMessages = function() {
    var topic = this.topic().replace(/"/g, '');
    this.addMessage({message: 'Welcome to ' + this.name() + '.'});
    this.addMessage({message: 'The topic is "' + topic + '".'});
  };

  // Called when this dialog is visible in gui
  proto._onShow = function() {
    if (this.messages().length >= 60) return;
    var self = this;
    self._api.messagesByDialog(
      { connection_id: self.connection().id(), dialog_id: self.name() },
      function(err, xhr) {
        if (err) return console.log(err);
        xhr.body.messages.forEach(function(msg) { self.addMessage(msg) });
        if (!self.messages().length) self._initialMessages();
        riot.update();
      }.bind(this)
    );
  };
})(window);
