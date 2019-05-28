import Operation from '../store/Operation';

export default class Api {
  constructor(url, params = {}) {
    this.debug = params.debug;
    this.url = url;
  }

  operation(operationId, defaultParams) {
    const op = new Operation({api: this, id: operationId, defaultParams});
    op.req.headers = {'Content-Type': 'application/json'};
    return op;
  }

  async spec(operationId) {
    if (this._op && operationId) return this._op[operationId];
    if (this._spec) return this._spec;

    const res = await fetch(this.url);
    const spec = await res.json();
    this._op = {};
    this._spec = spec;

    Object.keys(spec.paths).forEach(path => {
      Object.keys(spec.paths[path]).forEach(method => {
        const op = spec.paths[path][method];
        const operationId = op.operationId;
        if (!operationId) return;

        op.method = method.toUpperCase();
        op.url = spec.schemes[0] + '://' + spec.host + spec.basePath + path;
        op.parameters = (op.parameters || []).map(p => {
          if (!p['$ref']) return p;
          const refPath = p['$ref'].replace(/^#\//, '').split('/');
          let ref = spec;
          while (refPath.length) ref = ref[refPath.shift()];
          return ref;
        });

        this._op[operationId] = op;
      });
    });

    if (this._op && operationId) return this._op[operationId];
    if (this._spec) return this._spec;
  }
}
