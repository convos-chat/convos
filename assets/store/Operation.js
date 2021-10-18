/**
 * Operation is a class for fetching data from an OpenAPI powered server.
 *
 * @exports Operation
 * @class Operation
 * @extends Reactive
 * @property {Api} api An {@link Api} object.
 * @property {Array} err A list of errors, if any.
 * @property {Null} err If no errors.
 * @property {Object} defaultParams An Object holding default "Operation" parameters. (optional)
 * @property {Object} req The requested data.
 * @property {Object} res The response from the OpenAPI server.
 * @property {String} id The name of the operation ID.
 * @property {String} status Either "error", "loading", "pending" or "success".
 * @see Api
 */

import Reactive from '../js/Reactive';
import {is, regexpEscape} from '../js/util';

export default class Operation extends Reactive {
  constructor(params) {
    super();

    this.prop('ro', 'api', params.api);
    this.prop('ro', 'defaultParams', params.defaultParams || {});
    this.prop('ro', 'id', params.id);
    this.prop('rw', 'err', null);
    this.prop('rw', 'req', {body: null, headers: {}});
    this.prop('rw', 'res', {body: {}, headers: []});
    this.prop('rw', 'status', 'pending');
  }

  /**
   * error() can be used to get or set the "err" property.
   *
   * @example
   * op = op.err('Some error');
   * const err = op.err(); // "Some error"
   *
   * op = op.err([{message: 'Complex stuff', path: '/foo'}]);
   * const err = op.err(); // "foo: Complex stuff"
   *
   * @memberof Operation
   * @param {Array} err A list of error objects.
   * @param {String} err A descriptive error string.
   * @returns {String} A descriptive error string.
   */
  error(err) {
    // Set error
    if (err) return this.update({err: Array.isArray(err) ? err : [{message: err}], status: 'error'});

    // Get error
    if (!this.err || !this.err.length) return '';
    const first = this.err[0];
    const path = first.path && first.path.match(/\w$/) && first.path.split('/').pop();
    return path ? path + ': ' + first.message : first.message;
  }

  /**
   * perform() is used to send/receive data with the OpenAPI server.
   *
   * @example
   * await op.perform({email: 'jhthorsen@cpan.org'});
   * console.log(op.res.body);
   *
   * @memberof Operation
   * @param {Object} params Mapping between request parameter names and values.
   * @returns {Promise} The promise will be resolved on error and success.
   */
  perform(params) {
    let xhr;
    // this._promise is used as a locking mechanism so you can only call perform() once
    return this._promise || (this._promise = this.api.spec(this.id).then(opSpec => {
      if (!opSpec) throw 'Unknown operationId "' + this.id + '".';
      const req = this._paramsToRequest(opSpec, params || this.defaultParams);
      xhr = new XMLHttpRequest();
      this.update({req, status: 'loading'});
      return this._send(xhr, req);
    }).then(() => {
      const res = {};
      res.body = xhr.response ? JSON.parse(xhr.response) : {};
      res.headers = (xhr.getAllResponseHeaders() || '').trim().split(/[\r\n]+/).filter(l => l.length).map(h => h.split(/:\s*/, 2));
      res.status = String(xhr.status || '201');

      let err = null;
      if (!String(res.status).match(/^[23]/)) {
        err = res.body && res.body.errors ? res.body.errors : [{message: xhr.statusText || 'Unknown error.'}];
      }

      return this.update({err, res, status: err ? 'error' : 'success'});
    }).catch(err => {
      if (err.type) err = err.type;
      console.error(this.req.url + ' FAILED ' + err);
      this.update({res: {body: {errors: [{message: String(err)}]}, headers: [], status: '599'}, status: 'error'});
      return this.error(Array.isArray(err) ? err : 'Failed fetching operationId "' + this.id + '": ' + err);
    }).finally(() => {
      delete this._promise;
    }));
  }

  /**
   * is() can be used to check if the Operation is in a given state.
   *
   * @memberof Operation
   * @param {String} status Either "error", "loading", "pending" or "success".
   * @retuns {Boolean} True/false if the "status" property matches the input "status".
   */
  is(status) {
    return this.status == status;
  }

  /**
   * reset() can be used to clear the response with any data previously fetched.
   *
   * @memberof Operation
   */
  reset() {
    this.res.body = {};
    this.res.headers = {};
    this.res.status = 0;
    return this.update({err: null, status: 'pending'});
  }

  _extractValue(params, p) {
    return !p.schema ? params[p.name] : Object.keys(p.schema.properties).reduce((map, k) => { map[k] = params[k]; return map }, {});
  }

  _hasProperty(params, p) {
    if (p.in == 'body') return true;
    if (p.in == 'formData') return params.formData.has(p.name);
    return params.hasOwnProperty(p.name);
  }

  _paramsToRequest(opSpec, params) {
    const url = new URL(opSpec.url);
    const req = {headers: this.req.headers, method: opSpec.method.toLowerCase(), url};
    const errors = [];

    (opSpec.parameters || []).forEach(p => {
      if (!this._hasProperty(params, p) && p.required) {
        errors.push({message: 'Missing property.', path: '/' + p.name});
      }
      else if (!this._hasProperty(params, p) && !p.required) {
        return;
      }
      else if (p.in == 'path') {
        const re = new RegExp('(%7B|\\{)' + regexpEscape(p.name) + '(%7D|\\})', 'i');
        url.pathname = url.pathname.replace(re, encodeURIComponent(this._extractValue(params, p)));
      }
      else if (p.in == 'query') {
        url.searchParams.set(p.name, this._extractValue(params, p));
      }
      else if (p.in == 'formData') {
        delete req.headers['Content-Type'];
        req.body = params.formData;
      }
      else if (p.in == 'body') {
        req.body = this._extractValue(params, p);
      }
      else if (p.in == 'header') {
        req.header[p.name] = this._extractValue(params, p.name);
      }
      else {
        throw '[Api] Parameter in:' + p.in + ' is not supported.';
      }
    });

    if (errors.length) throw errors;
    return req;
  }

  _send(xhr, req) {
    // Have to use XMLHttpRequest, since fetch() does not seem to support "progress" event
    xhr.timeout = 15000; // TODO: Is this a good value?
    xhr.open(req.method.toUpperCase(), req.url);
    Object.keys(req.headers).forEach(k => xhr.setRequestHeader(k, req.headers[k]));

    if (req.method == 'post') {
      xhr.upload.addEventListener('progress', e => this.emit('progress', e));
      xhr.send(is.object(req.body) && !is.function(req.body.has) ? JSON.stringify(req.body) : req.body);
    }
    else {
      xhr.send();
    }

    return new Promise(resolve => {
      xhr.addEventListener('abort', resolve);
      xhr.addEventListener('error', resolve);
      xhr.addEventListener('load', resolve);
    });
  }
}
