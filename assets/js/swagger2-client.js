(function() {
  /*
    var client = new swaggerClient(url, function(err) {
      this.listPets({limit: 10}, function(err, xhr) {
        console.log(xhr.code, xhr.body);
      });
    });
  */
  window.swaggerClient = function(spec, cb) {
    this._id = 1;
    this._xhr = {};
    if (typeof spec == 'object') return this.generate(spec);
    if (typeof spec == 'string') return this.load(spec, cb);
  };

  var proto = window.swaggerClient.prototype;
  var cache = {}, makeErr;

  // Get cached response
  // xhr = client.cached(operationId);
  // xhr = client.cached("listPets");
  proto.cached = function(operationId) { return cache[operationId]; };

  proto.clearCache = function() { cache = {}; };

  // Force using plain HTTP instead of WebSocket
  // client.http().listPets({}, function(err, xhr) {});
  proto.http = function() { this._http = true; return this; };

  // Force getting fresh data from server
  // client.fresh().listPets({}, function(err, xhr) {});
  proto.fresh = function() { this._fresh = true; return this; };

  // Add methods with operationId names to client from Swagger spec
  // client.generate({swagger: "2.0", ...});
  proto.generate = function(spec) {
    var self = this;
    this.baseUrl = (spec.basePath || '').replace(/\/$/, '');
    this._fresh = false;

    // Generate methods from spec
    Object.keys(spec.paths).forEach(function(path) {
      if (path.indexOf('/') != 0) return;
      Object.keys(spec.paths[path]).forEach(function(httpMethod) {
        if (!httpMethod.match(/^\w+$/)) return;
        var opSpec = spec.paths[path][httpMethod];
        var pathList = path.split('/');
        httpMethod = httpMethod.toUpperCase();
        pathList.shift(); // first element is empty string

        if (window.DEBUG == 2) console.log('[Swagger] Add method ' + opSpec.operationId);
        self[opSpec.operationId] = function(input, cb) {
          var xhr = this._fresh ? false : this.cached(opSpec.operationId);
          var http = this._http;

          delete this._fresh; // reset on each request
          delete this._http; // reset on each request

          if (xhr) {
            if (window.DEBUG) console.log('[Swagger] ' + xhr.url + ' is cached');
            setTimeout(function() { cb.call(this, null, xhr) }.bind(this), 0);
          }
          else if(!http && this._ws && this._ws.readyState == WebSocket.OPEN) {
            this._ws.send({id: this._id, op: opSpec.operationId, params: input});
            this._xhr[this._id++] = cb;
            cb.op = opSpec.operationId;
          }
          else {
            xhr = this.req(httpMethod, pathList, input, opSpec.parameters || []);
            if (xhr.errors) {
              setTimeout(function() { cb.call(this, xhr.errors, xhr) }.bind(this), 0);
            }
            else {
              xhr.onreadystatechange = function() {
                if (xhr.readyState != 4) return;
                if (httpMethod == 'GET' && xhr.status == 200) cache[httpMethod + ':' + xhr.url] = xhr;
                if (window.DEBUG) console.log('[Swagger] ' + xhr.url + ' ' + xhr.status + ' ' + xhr.responseText);
                xhr.body = xhr.responseText.match(/^[\{\[]/) ? JSON.parse(xhr.responseText) : xhr.responseText;
                cb.call(this, makeErr(xhr), xhr);
              }.bind(this);
              xhr.send(xhr.body);
              delete xhr.body;
            }
          }

          return this;
        };
      });
    });
  };

  // Load spec from URL
  // client = client.load(url, function(err) { ... });
  proto.load = function(url, cb) {
    var xhr = new XMLHttpRequest();

    xhr.open('GET', url);
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) return;
      if (xhr.status != 200) return cb.call(this, xhr.status);
      if (window.DEBUG == 1) console.log('[Swagger] Generate methods from ' + url);
      this.generate(xhr.responseText.match(/^[\{\[]/) ? JSON.parse(xhr.responseText) : {});
      cb.call(this, '');
    }.bind(this);
    xhr.send(null);

    return this;
  };

  proto.ws = function(ws) {
    var self = this;
    self._ws = ws;
    ws.on('json', function(res) {
      if (!res.id || !res.code) return;
      var xhr = self._xhr[res.id];
      if (!xhr) return;
      delete self._xhr[res.id];
      xhr.status = res.code;
      xhr.body = res.body;
      if (window.DEBUG) console.log('[Swagger] ' + xhr.op + ' ' + xhr.status + ' ' + JSON.stringify(xhr.body));
      xhr.call(self, makeErr(xhr), xhr);
    });
    return self;
  };

  // Create XMLHttpRequest object
  // xhr = client.req([...], {...}, {...});
  proto.req = function(httpMethod, pathList, input, parameters) {
    var xhr = new XMLHttpRequest();
    var form = [], headers = [], json = null, query = [], str;
    var url = [this.baseUrl];
    var errors = [];

    pathList.forEach(function(p) {
      url.push(p.replace(/\{(\w+)\}/, function(m, n) {
        if (typeof input[n] == 'undefined') errors.push({message: 'Missing input: ' + n, path: '/' + n});
        return input[n];
      }));
    });

    xhr.body = null;
    xhr.url = url.join('/');

    for (i = 0; i < parameters.length; i++) {
      var p = parameters[i];
      var name = p.name;
      var value = input[name];

      if (typeof value == 'undefined') {
        value = p['default'];
      }
      if (typeof value == 'undefined') {
        if (p.required) errors.push({message: 'Missing input: ' + name, path: '/' + name});
        continue;
      }

      switch (p['in']) {
        case 'body':     json = value;                break;
        case 'file':     xhr.body = value;            break;
        case 'formData': form.push([name, value]);    break;
        case 'header':   headers.push([name, value]); break;
        case 'query':    query.push([name, value]);   break;
      }
    }

    if (errors.length) {
      if (window.DEBUG) console.log('[Swagger] ' + xhr.url + ' = ' + JSON.stringify(errors));
      xhr.errors = errors;
      return xhr;
    }
    if (query.length) {
      str = [];
      query.forEach(function(i) { str.push(encodeURIComponent(i[0]) + '=' + encodeURIComponent(i[1])); });
      xhr.url += '?' + str.join('&');
    }

    if (json) {
      headers.unshift(['Content-Type', 'application/json']);
      xhr.body = JSON.stringify(json);
      if (window.DEBUG == 2) console.log('[Swagger] ' + xhr.url + ' <<< ' + xhr.body);
    }
    else if(form.length) {
      str = [];
      headers.unshift(['Content-Type', 'application/x-www-form-urlencoded']);
      form.forEach(function(i) { str.push(encodeURIComponent(i[0]) + '=' + encodeURIComponent(i[1])); });
      xhr.body = str.join('&');
      if (window.DEBUG == 2) console.log('[Swagger] ' + xhr.url + ' <<< ' + xhr.body);
    }

    xhr.open(httpMethod, xhr.url);
    headers.forEach(function(i) { xhr.setRequestHeader(i[0], i[1]); });

    return xhr;
  };

  var makeErr = function(xhr) {
    var errors = xhr.body.errors || [];
    if (xhr.status == 200) return null;
    if (errors.length) return errors;
    if (!xhr.status) xhr.status = 408;
    return [{message: "Something very bad happened! Try again later. (" + xhr.status + ")", path: xhr.url}];
  };
})(window);
