(function(window) {
  Convos.Dialog = function(attrs) {
    if (attrs) this.update(attrs);
    this._api = Convos.api;
    riot.observable(this);
    this.on('message', this.addMessage);
    this.on('message', function() { riot.update() });
    this.on('users', this._onUsers);
    this.one('show', this._load);
  };

  var proto = Convos.Dialog.prototype;

  // Define attributes
  mixin.base(proto, {
    connection: function() { throw 'connection() cannot be built'; },
    frozen: function() { return '' },
    icon: function() { return this.is_private() ? 'person' : 'group' },
    id: function() { return '' },
    is_private: function() { return true; },
    messages: function() { return []; },
    name: function() { return 'Convos' },
    topic: function() { return '' }
  });

  proto.addMessage = function(msg) {
    if (!msg.from) msg.from = 'convosbot';
    if (!msg.ts) msg.ts = new Date();
    if (typeof msg.ts == 'string') msg.ts = new Date(msg.ts);
    if (msg.message && this._connection) this.connection().highlightMessage(msg);
    this.messages().push(msg);
  };

  proto.groupedMessage = function(msg) {
    var prev = this.prevMessage || {ts: new Date()};
    this.prevMessage = msg;
    if (!msg.message) return false;
    return msg.from == prev.from && msg.ts.epoch() - 300 < prev.ts.epoch();
  }

  proto.hasConnection = function() {
    return this._connection ? true : false;
  };

  // Create a href for <a> tag
  proto.href = function() {
    var path = Array.prototype.slice.call(arguments);
    return ['#chat', this.connection().id(), this.name()].concat(path).join('/');
  };

  proto.participants = function(cb) {
    var self = this;
    if (!cb) return this._participants;
    this._api.participantsInDialog(
      {
        connection_id: this.connection().id(),
        dialog_id: this.name()
      },
      function(err, xhr) {
        if (!err) self._participants = xhr.body.participants;
        cb.call(self, err, xhr.body);
      }
    );
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
      function(err, xhr) {
        var action = command.match(/^\/(\w+)/);
        if (cb) {
          cb.call(self, err, xhr.body);
        }
        else if (err) {
          self.addMessage({type: 'error', message: 'Could not send "' + command + '": ' + err[0].message});
        }
        else if (!action) {
          return; // nothing to do
        }
        else {
          var handler = '_on' + action[1].toLowerCase().ucFirst() + 'Event';
          if (self[handler]) {
            self[handler](xhr.body);
          }
          else {
            console.log('Unable to handle response from "' + xhr.body.command + '".');
          }
        }
        riot.update();
      }
    );
    return this;
  };

  proto._initialMessages = function() {
    var topic = this.topic().replace(/"/g, '') || '';
    this.addMessage({message: 'You have joined ' + this.name() + ', but no one has said anything as long as you have been here.'});
    if (this.frozen()) {
      this.addMessage({message: 'You are not part of this channel. The reason is ' + this.frozen()});
    }
    if(!this.is_private()) {
      this.participants(function(err, participants) { riot.update(); });
    }
  };

  // Called when this dialog is visible in gui the first time
  proto._load = function() {
    if (!this.hasConnection()) return;
    if (this.messages().length >= 60) return;
    var self = this;
    self._api.messagesByDialog(
      {connection_id: self.connection().id(), dialog_id: self.name()},
      function(err, xhr) {
        if (err) return console.log(err);
        xhr.body.messages.forEach(function(msg) { self.addMessage(msg) });
        if (!self.messages().length) self._initialMessages();
        riot.update();
      }.bind(this)
    );
  };

  proto._onUsers = function(data) {
    var msg = {from: this.connection().id(), ts: data.ts, type: 'notice'};
    if (data.new_nick) {
      msg.message = data.nick + ' changed nick to ' + data.new_nick + '.';
    }
    else if (data.message) {
      msg.message = data.message;
    }
    else {
      msg.message = JSON.encode(data);
    }

    this.trigger('message', msg);
  };

  proto._onWhoisEvent = function(res) {
    var channels = Object.keys(res.channels || {});
    var id = [res.user];
    if (res.name) id.push(res.name);
    id = res.nick + ' (' + id.join(' - ') + ')';
    this.trigger('message', {type: 'notice', message: id + ' has been ide for ' + res.idle_for + ' seconds in ' + channels.join(', ') + '.'});
  };

  proto._onTopicEvent = function(res) {
    if (res.message) return this.trigger('message', {type: 'notice', message: 'Topic is: ' + res.message});
    return this.trigger('message', {type: 'notice', message: 'No topic is set.'});
  };
})(window);
