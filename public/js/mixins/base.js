(window['mixin'] = window['mixin'] || {})['base'] = function(caller, attrs) {
  var persistent = window.localStorage || {};
  var hasPersistent = function(name) { return (persistent[name] || '').match(/^\[/); };
  var data = {};

  // allow obj.on("eventName", function() { ... });
  riot.observable(caller);

  // clear attribute
  caller.clear = caller.clear || function(name) {
    var value = data[name];
    delete data[name];
    return value;
  }

  // allow chaining
  // obj.tap(function() { .... }) == obj
  // obj.tap("attrName", value) == obj
  caller.tap = function(cb) {
    if (typeof cb == 'string') {
      this[cb] = arguments[1];
    }
    else {
      cb.apply(this, Array.prototype.slice.call(arguments, 1));
    }
    return this;
  };

  // define attributes
  Object.keys(attrs).forEach(function(name) {
    var def = attrs[name];

    caller[name] = function(value) {
      if (arguments.length) {
        if (def[1]) persistent[name] = JSON.stringify([value]);
        data[name] = value;
        this.trigger(name, value);
        return this;
      }
      else {
        return (
            data.hasOwnProperty(name) ? data[name]
          : hasPersistent(name) ? JSON.parse(persistent[name])[0]
          : def[0]()
        );
      }
    };
  });

  return caller;
};
