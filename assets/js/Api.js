export class Api {
  constructor(url, params = {}) {
    this.debug = params.debug;
    this.url = url;
    this.op = {};
  }

  async execute(operationId, params = {}) {
    let api = await this._api();
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
        else if (p.in == 'path') {
          const re = new RegExp('(%7B|\\{)' + p.name + '(%7D|\\})', 'i');
          url.pathname = url.pathname.replace(re, this._extractValue(params, p));
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
        else {
          throw '[Api] Parameter in:' + p.in + ' is not supported.';
        }
    });

    if (this.debug) {
      console.log('[Api]', operationId, '===', op);
      console.log('[Api]', url.href, '<<<', fetchParams);
    }

    let res = await fetch(url, fetchParams);
    let json = res.json();
    json.headers = res.headers;
    if (String(res.status).indexOf('2') == 0) return json;
    ['status', 'statusText'].forEach(k => { json[k] = res[k] });
    throw json;
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
            const op = api.paths[path][method];
            const operationId = op.operationId;
            if (!operationId) return;

            op._method = method.toUpperCase();
            op._url = api.schemes[0] + '://' + api.host + api.basePath + path;
            op.parameters = (op.parameters || []).map(p => {
              if (!p['$ref']) return p;
              const refPath = p['$ref'].replace(/^\#\//, '').split('/');
              let ref = api;
              while (refPath.length) ref = ref[refPath.shift()];
              return ref;
            });

            this.op[operationId] = op;
          });
        });
        return api;
      });
    }
    return this.apiPromise;
  }
}
