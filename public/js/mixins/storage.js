(window['mixin'] = window['mixin'] || {})['storage'] = function(caller, attrs) {
  var persistent = window.localStorage || {};
  var hasPersistent = function(name) { return (persistent[name] || '').match(/^\[/); };
  var data = {};

  riot.observable(caller);

  caller.clear = caller.clear || function(name) {
    var value = data[name];
    delete data[name];
    return value;
  }

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
