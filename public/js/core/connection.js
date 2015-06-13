(function(window) {
  // connection = Object.create(Convos.Connection);
  var Connection = {_conversations: {}, _method: 'httpCachedGet'};

  // Define attributes
  mixin.base(Connection, {
    name: [function() {return ''}, false],
    state: [function() {return ''}, false],
    type: [function() {return ''}, false],
    url: [function() {return ''}, false]
  });

  // Write connection settings to server
  Connection.save = function(data, cb) {
    if (!cb) {
      if (typeof data.name != 'undefined') this.name(data.name);
      if (typeof data.state != 'undefined') this.state(data.state);
      if (typeof data.type != 'undefined') this.type(data.type);
      if (typeof data.url != 'undefined') this.url(data.url);
      return this;
    }

    this.httpPost(apiUrl('/connection/TODO'), data, function(err, xhr) {
      if (err) return cb.call(this, err);
      this.save(data);
      cb.call(this, err);
    });
  };

  (window['Convos'] = window['Convos'] || {})['Connection'] = Connection;
})(window);
