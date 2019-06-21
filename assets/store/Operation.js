import Reactive from '../js/Reactive';

const validStatus = ['error', 'loading', 'pending', 'success'];

export default class Operation extends Reactive {
  constructor(params) {
    super();

    this._readOnlyAttr('api', params.api);
    this._readOnlyAttr('defaultParams', params.defaultParams || {});
    this._readOnlyAttr('id', params.id);
    this._readOnlyAttr('req', {body: null, headers: {}});
    this._readOnlyAttr('res', {body: {}, headers: {}});
    this._updateableAttr('err', null);
    this._updateableAttr('status', 'pending');
  }

  error(err) {
    if (err) { // Set error
      return this.update({err: Array.isArray(err) ? err : [{message: err}], status: 'error'});
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

    this.update({status: 'loading'});
    const [url, req] = await this._paramsToRequest(opSpec, params || this.defaultParams);
    const res = await fetch(url, req);
    const json = await res.json();
    return this.parse(res, json);
  }

  is(status) {
    if (validStatus.indexOf(status) == -1) throw 'Invalid status: ' + status;
    return this.status == status;
  }

  parse(res, body = res.body) {
    this.res.body = body || res;
    this.res.status = res.status || '201';
    this.res.statusText = res.statusText;
    if (res.headers) this.res.headers = res.headers;

    let err = null;
    if (!String(this.res.status).match(/^[23]/)) {
      err = body && body.errors ? body.errors : [{message: res.statusText || 'Unknown error.'}];
    }

    return this.update({err, status: err ? 'error' : 'success'});
  }

  reset() {
    this.res.body = {};
    this.res.headers = {};
    this.res.status = 0;
    return this.update({err: null, status: 'pending'});
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
