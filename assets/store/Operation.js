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
    this.prop('ro', 'req', {body: null, headers: {}});
    this.prop('ro', 'res', {body: {}, headers: {}});
    this.prop('rw', 'err', null);
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
   * @param {String} source A name of where the error occured.
   * @returns {String} A descriptive error string.
   */
  error(err, source) {
    // Set error
    if (err) return this.update({err: Array.isArray(err) ? err : [{message: err, source: source}], status: 'error'});

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
    // this._promise is used as a locking mechanism so you can only call perform() once
    return this._promise || (this._promise = new Promise(resolve => {
      this.api.spec(this.id).then(opSpec => {
        if (!opSpec) throw 'Unknown operationId "' + this.id + '".';

        const [url, req] = this._paramsToRequest(opSpec, params || this.defaultParams);
        if (!url) throw req;

        this.update({status: 'loading'});
        if (is.object(req.body) && !is.function(req.body.has)) req.body = JSON.stringify(req.body);
        return fetch(url, req);
      }).then(res => {
        return Promise.all([res, res.json()]);
      }).then(([res, json]) => {
        delete this._promise;
        resolve(this.parse(res, json));
      }).catch(err => {
        delete this._promise;
        resolve(this.error(Array.isArray(err) ? err : 'Failed fetching operationId "' + this.id + '": ' + err, 'fetch'));
      });
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
   * Used to parse a response body
   *
   * @param {Response} res
   * @param {Object} body
   */
  parse(res, body = res.body) {
    this.res.body = body || res;
    this.res.status = res.status || '201';
    if (res.headers) this.res.headers = res.headers;

    let err = null;
    if (!String(this.res.status).match(/^[23]/)) {
      err = body && body.errors ? body.errors : [{message: res.statusText || 'Unknown error.'}];
    }

    return this.update({err, status: err ? 'error' : 'success'});
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
    const fetchParams = {headers: this.req.headers, method: opSpec.method};
    const url = new URL(opSpec.url);
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
        delete fetchParams.headers['Content-Type']; // Set by fetch()
        fetchParams.body = params.formData;
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

    return errors.length ? [null, errors] : [url, fetchParams];
  }
}
