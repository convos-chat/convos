export class Api {
  constructor(url, params = {}) {
    this.debug = params.debug;
    this.url = url;
    this.op = {};
  }

  execute(operationId, params = {}) {
    return this._api().then(api => {
      const op = this.op[operationId];
      if (!op) throw '[Api] Invalid operationId: ' + operationId;

      const url = new URL(op._url);
      const fetchParams = {
        headers: {'Content-Type': 'application/json'},
        method: op._method,
      };

      (op.parameters || []).forEach(p => {
        if (!this._hasProperty(params, p) && !p.required) {
          return;
        }
        else if (p.in == 'query') {
          url.searchParams.set(p.name, this._extractValue(params, p));
        }
        else if (p.in == 'body') {
          fetchParams.body = this._extractValue(params, p);
        }
        else if (p.in == 'header') {
          fetchParams.header[p.name] = this._extractValue(params, p.name);
        }
      });

      if (this.debug) {
        console.log('[Api]', operationId, '===', op);
        console.log('[Api]', url.href, '<<<', fetchParams);
      }

      return fetch(url, fetchParams).then(res => Promise.all([res, res.json()])).then(([res, json]) => {
        json.headers = res.headers;
        if (String(res.status).indexOf('2') == 0) return json;
        ['status', 'statusText'].forEach(k => { json[k] = res[k] });
        throw json;
      });
    });
  }

  _extractValue(params, p) {
    if (p.schema && (params.tagName || '').toLowerCase() == 'form' ) {
      const body = {};
      Object.keys(p.schema.properties).forEach(k => { body[k] = params[k] && params[k].value });
      return JSON.stringify(body);
    }
    else if (params[p.name] && params[p.name].tagName) {
      return params[p.name].value;
    }
    else {
      return params[p.name];
    }
  }

  _hasProperty(params, p) {
    if ((params.tagName || '').toLowerCase() == 'form') {
      return p.in == 'body' ? true : params[p.name] ? true : false;
    }
    else {
      return params.hasOwnProperty(p.name);
    }
  }

  _api() {
    if (!this.apiPromise) {
      this.apiPromise = fetch(this.url).then(res => res.json()).then(api => {
        Object.keys(api.paths).forEach(path => {
          Object.keys(api.paths[path]).forEach(method => {
            const operationId = api.paths[path][method].operationId;
            if (!operationId) return;
            api.paths[path][method]._method = method.toUpperCase();
            api.paths[path][method]._url = api.schemes[0] + '://' + api.host + api.basePath + path;
            this.op[operationId] = api.paths[path][method];
          });
        });
        return api;
      });
    }
    return this.apiPromise;
  }
}