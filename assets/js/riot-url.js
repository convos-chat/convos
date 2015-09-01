(function(window) {
  riot.Url = function(o) {
    riot.observable(this);
    this._query = {};
    if (typeof o == 'string') this.parse(o);
    if (typeof o == 'object') Object.keys(o).forEach(function(k) { this[k] = o[k]; }.bind(this));
  };

  var proto = riot.Url.prototype;

  ['fragment', 'host', 'path', 'port', 'scheme'].forEach(function(_m) {
    var m = _m;
    proto[m] = function(v) {
      if (arguments.length) { this['_' + m] = v; return this; }
      return this['_' + m];
    };
  });

  proto.hostPort = function(str) {
    if (arguments.length) {
      var hp = str.split(':');
      this.host(hp[0]);
      if (hp[1]) this.port(hp[1]);
      return this;
    }
    else if (this.port()) {
      return [this.host(), this.port()].join(':');
    }
    else {
      return this.host();
    }
  };

  proto.parse = function(str) {
    var scheme, parser = document.createElement('a');

    parser.href = str.replace(/^(\w+):\/\//, function(a, s) { scheme = s; return 'http://'; });

    this._raw = str;
    this._fragment = parser.hash.replace(/^\#/, '');
    this._host = parser.host.replace(/:\w+$/, '');
    this._userinfo = parser.username || '';
    this._hostPort = parser.host;
    this._path = parser.pathname;
    this._port = parser.port;
    this._query = {};
    this._scheme = scheme;

    if (parser.password) this._userinfo += ':' + parser.password;

    parser.search.replace(/^\?/, '').split('&').forEach(function(i) {
      var kv = i.split('=');
      this._query[kv[0]] = kv[1];
    }.bind(this));

    return this;
  };

  proto.query = function(k, v) {
    if (arguments.length == 1) return this._query[k];
    if (arguments.length == 2) { this._query[k] = v; return this; }
    return this._query;
  };

  proto.toString = function() {
    var q = this._query;
    var v, str = '';
    if (v = this.scheme()) str += v + '://';
    if (v = this.userinfo()) str += v + '@';
    if (v = this.hostPort()) str += v;
    if (Object.keys(q).length) str += '?' + Object.keys(q).map(function(k) { return k + '=' + q[k]; }).join('&');
    if (v = this.fragment()) str += '#' + v;
    return str;
  };

  proto.userinfo = function(u, p) {
    if (arguments.length == 2) u = [u || '', p].join(':');
    if (arguments.length) { this._userinfo = u; return this; }
    return this._userinfo || '';
  };

  riot.url = new riot.Url().parse(window.location.href);

  // same as riot.route(), but will always trigger "update"
  riot.url.route = function(path) {
    if (path == riot.url._raw) {
      riot.url.trigger('update', riot.url);
    }
    else {
      riot.route(path);
    }
  };

  // Listen for changes in location and update riot
  riot.route(function() {
    riot.url.parse(window.location.href);
    riot.url.trigger('update', riot.url);
    riot.update();
  });

  riot.route.start();
})(window);
