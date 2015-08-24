(window['mixin'] = window['mixin'] || {})['base'] = function(proto, attributes) {

  proto._attrs = {};

  // define attribute getter/setter
  Object.keys(attributes || {}).forEach(function(n, i) {
    var builder = attributes[n];
    var name = n;
    proto._attrs[name] = true;
    proto[name] = function(value) {
      if (arguments.length) {
        this['_' + name] = value;
        if (this.trigger) this.trigger(name, value);
        return this;
      }
      else if(this.hasOwnProperty('_' + name)) {
        return this['_' + name];
      }
      else {
        return this['_' + name] = builder.call(this);
      }
    };
  });

  // clear attribute
  proto.clear = function(name) {
    var value = this['_' + name];
    delete this['_' + name];
    return value;
  };

  // update attributes to object
  proto.update = function(attrs) {
    var self = this;
    Object.keys(attrs).forEach(function(k) {
      return proto._attrs[k] ? self[k](attrs[k]) : 0; // console.log(self, ' missing attribute for ' + k);
    });
    if (this.trigger) this.trigger('updated', attrs);
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

  proto.DESTROY = function() {
    if (this.trigger) this.trigger('DESTROY');
    for (k in this) {
      if (!this.hasOwnProperty(k)) continue;
      else if (typeof this[k] != 'object') continue;
      else if (typeof this[k]['close'] == 'function') this[k].close();
      else if (typeof this[k]['finish'] == 'function') this[k].finish();
      else if (typeof this[k]['DESTROY'] == 'function') this[k].DESTROY();
    }
  };

  return proto;
};
