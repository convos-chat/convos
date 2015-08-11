(window['mixin'] = window['mixin'] || {})['base'] = function(proto, attributes) {

  // define attribute getter/setter
  Object.keys(attributes || {}).forEach(function(n, i) {
    var builder = attributes[n];
    var name = n;
    proto[name] = function(value) {
      if (arguments.length) {
        this['_' + name] = value;
        if (this.trigger) this.trigger(name, value);
        return this;
      }
      else {
        return this.hasOwnProperty('_' + name) ? this['_' + name] : builder.call(this);
      }
    };
  });

  // clear attribute
  proto.clear = function(name) {
    var value = this['_' + name];
    delete this['_' + name];
    return value;
  };

  // save attributes to object
  proto.save = function(attrs) {
    Object.keys(attrs).forEach(function(k) { if (typeof this[k] == 'function') this[k](attrs[k]); }.bind(this));
    if (this.trigger) this.trigger('updated');
    return this;
  };

  // allow chaining
  // obj.tap(function() { .... }) == obj
  // obj.tap("attrName", value) == obj
  proto.tap = function(cb) {
    if (typeof cb == 'string') {
      this[cb] = arguments[1];
    }
    else {
      cb.apply(this, Array.prototype.slice.call(arguments, 1));
    }
    return this;
  };

  return proto;
};
