/**
 * Api is a class for loading an OpenAPI spec that you can fetch operations from.
 *
 * @exports Api
 * @class Api
 * @property {String} url An URL to the OpenAPI specification.
 * @see Operation
 */

import Operation from '../store/Operation';
import Reactive from './Reactive';
import {is} from '../js/util';

export const api = (id, operationId, params) => {
  const singleton = api.singletons[id] || (api.singletons[id] = new Api());
  return operationId ? singleton.operation(operationId, params) : singleton;
};

api.singletons = {};

class Api extends Reactive {
  constructor() {
    super();
    this.prop('rw', 'protocol', location.protocol || 'http');
    this.prop('rw', 'url', '');
  }

  /**
   * operation() is used to create a new {@link Operation} object by operation
   * ID.
   *
   * @example
   * const getUserOp = api.operation('getUser');
   * const getUserOp = api.operation('getUser', {connections: true});
   *
   * @memberof Api
   * @param {String} operationId An operation ID in the spec.
   * @param {Object} defaultParams An Object holding default "Operation" parameters. (optional)
   * @returns An Operation object.
   */
  operation(operationId, defaultParams) {
    const op = new Operation({api: this, id: operationId, defaultParams});
    op.req.headers = {'Content-Type': 'application/json'};
    return op;
  }

  /**
   * spec() will return the specification for a given operation Id or the whole
   * spec, if no operation is specified.
   *
   * @example
   * const apiSpec = await api.spec();
   * const getUserOpSpec = await api.spec('getUser');
   *
   * @memberof Api
   * @param {String} operationId An operation ID in the spec.
   * @returns {Object} Either the complete API spec or the spec for a single operation.
   */
  async spec(operationId) {
    if (this._ops && operationId) return this._ops[operationId];
    if (this._spec) return this._spec;

    const res = await fetch(this.url);
    const spec = await res.json();
    this._ops = {};
    this._spec = spec;

    Object.keys(spec.paths).forEach(path => {
      Object.keys(spec.paths[path]).forEach(method => {
        const op = spec.paths[path][method];
        const operationId = op.operationId;
        if (!operationId) return;

        op.method = method.toUpperCase();
        op.url = this.protocol + '//' + spec.host + spec.basePath + path + '.json';
        op.parameters = (op.parameters || []).map(p => this._resolveRef(p));

        this._ops[operationId] = op;
      });
    });

    if (this._ops && operationId) return this._ops[operationId];
    if (this._spec) return this._spec;
  }

  /**
   * Turns the object into a function.
   *
   * @example
   * const api = new Api().toFunction();
   * api('getUser', {}) == api().operation('getUser', {});
   *
   * @memberof Api
   * @returns {Function}
   */
  toFunction() {
    return (operationId, params) => operationId ? this.operation(operationId, params) : this;
  }

  _resolveRef(p) {
    let res = p;

    if (p['$ref']) {
      const refPath = p['$ref'].replace(/^#\//, '').split('/');
      res = this._spec;
      while (refPath.length) res = res[refPath.shift()];
    }

    if (is.object(res)) {
      Object.keys(res).forEach(k => {
        res[k] = this._resolveRef(res[k]);
      });
    }

    return res;
  }
}
