const validStatus = {error: true, loading: true, pending: true, success: true};

export default class Operation {
  constructor(params) {
    // Read-only properties
    ['api', 'defaultParams', 'id'].forEach(name => {
      Object.defineProperty(this, name, {value: params[name], writable: false});
    });

    this.err = null;
    this.res = {body: {}, headers: {}};
    this.req = {body: null, headers: {}};
    this.subscribers = [];
    this._status = 'pending';
  }

  error(err) {
    if (err) { // Set error
      this.err = Array.isArray(err) ? err : [{message: err}];
      return this._notifySubscribers('error');
    }
    else if (!this.err || !this.err.length) { // No error
      return '';
    }
    else { // Get error
      const first = this.err[0];
      const path = first.path && first.path.match(/\w$/) && first.path.split('/').pop();
      return path ? path + ': ' + first.message : first.message;
    }
  }

  async perform(params) {
    const opSpec = await this.api.spec(this.id);
    if (!opSpec) return this.error('Invalid operationId "' + this.id + '".');

    this._notifySubscribers('loading');
    const [url, req] = await this._paramsToRequest(opSpec, params || this.defaultParams);
    const res = await fetch(url, req);
    const json = await res.json();
    return this.parse(res, json);
  }

  is(status) {
    const statusIs = this._status == status;
    if (!validStatus[status]) throw 'Invalid status: ' + status;
    return statusIs;
  }

  parse(res, body = res.body) {
    this.res.body = body || res;
    this.res.status = res.status || '201';
    this.res.statusText = res.statusText;
    if (res.headers) this.res.headers = res.headers;

    if (String(this.res.status).match(/^[23]/)) {
      this.err = null;
      return this._notifySubscribers('success');
    }
    else {
      this.err = body && body.errors ? body.errors : [{message: res.statusText || 'Unknown error.'}];
      return this._notifySubscribers('error');
    }
  }

  reset() {
    this.res = {body: {}, headers: {}};
    this.err = null;
    this._notifySubscribers('pending');
  }

  // This is used by https://svelte.dev/docs#svelte_store
  subscribe(cb) {
    this.subscribers.push(cb);
    cb(this);
    return () => this.subscribers.filter(i => (i != cb));
  }

  _extractValue(params, p) {
    if (p.schema && (params.tagName || '').toLowerCase() == 'form' ) {
      const body = {};
      Object.keys(p.schema.properties).forEach(k => { body[k] = params[k] && params[k].value });
      return body;
    }
    else if (params[p.name] && params[p.name].tagName) {
      return params[p.name].value;
    }
    else if (p.schema) {
      const body = {};
      Object.keys(p.schema.properties).forEach(k => { body[k] = params[k] });
      return body;
    }
    else {
      return params[p.name];
    }
  }

  _hasProperty(params, p) {
    if (p.in == 'body') {
      return true;
    }
    else if ((params.tagName || '').toLowerCase() == 'form') {
      return params[p.name] ? true : false;
    }
    else {
      return params.hasOwnProperty(p.name);
    }
  }

  _notifySubscribers(status) {
    if (!validStatus[status]) throw 'Invalid status: ' + status;
    this._status = status;
    this.subscribers.forEach(cb => cb(this));
    return this;
  }

  _paramsToRequest(opSpec, params) {
    const fetchParams = {headers: this.req.headers, method: opSpec.method};
    const url = new URL(opSpec.url);

    (opSpec.parameters || []).forEach(p => {
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

    if (fetchParams.hasOwnProperty('body')) {
      fetchParams.body = JSON.stringify(fetchParams.body);
    }

    return [url, fetchParams];
  }
}
