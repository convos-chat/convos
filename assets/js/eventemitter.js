var EventEmitter = function(obj) {
  obj._events = {};
  ["emit", "hasSubscribers", "on", "once", "unsubscribe"].forEach(function(n) {
    obj[n] = EventEmitter.prototype[n];
  });
};

EventEmitter.prototype.emit = function() {
  var args = Array.prototype.slice.call(arguments);
  var name = args.shift();
  var cb   = this._events[name];

  if (cb) {
    cb.forEach(function(i) {
      try {
        i.apply(this, args);
      } catch ( e ) {
        this.emit("error", e);
      }
    }.bind(this));
  } else if (name == "error") {
    throw JSON.stringify(args);
  }

  return this;
};

EventEmitter.prototype.hasSubscribers = function(name) {
  var cb = this._events[name];
  return cb && cb.length ? true : false;
};

EventEmitter.prototype.on = function(name, cb) {
  if (!this._events[name])
    this._events[name] = [];
  this._events[name].push(cb);
  return this;
};

EventEmitter.prototype.once = function(name, cb) {
  var wrapper = function() {
    this.unsubscribe(name); cb.apply(this, arguments);
  }.bind(this);
  this.on(name, wrapper);
};

EventEmitter.prototype.unsubscribe = function(name, cb) {
  if (this._events[name]) {
    if (cb) {
      this._events[name] = this._events[name].filter(function(i) {
        return i != cb;
      });
    } else {
      delete this._events[name];
    }
  }
  return this;
};
