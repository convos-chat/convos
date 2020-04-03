import Reactive from '../js/Reactive';
import page from 'page';

export default class Route extends Reactive {
  constructor() {
    super();

    this.prop('ro', 'basePath', () => this._basePath);
    this.prop('ro', 'canonicalPath', () => this.ctx.canonicalPath);
    this.prop('ro', 'hash', () => location.hash);
    this.prop('ro', 'pathParts', () => this.ctx.pathname.split('/').filter(p => p.length));
    this.prop('ro', 'title', () => this.ctx.title);

    this.prop('rw', 'activeMenu', '');
    this.prop('rw', 'baseUrl', '');
    this.prop('rw', 'component', null);
    this.prop('rw', 'ctx', {canonicalPath: '/', params: {}, pathname: '/', state: {}, title: document.title});
    this.prop('rw', 'query', {});
    this.prop('rw', 'requireLogin', false);

    this.prop('persist', 'lastUrl', '');

    this._basePath = '';
    this._history = window.history;
    this._page = page;
    this._started = false;
  }

  go(path, state, replace = false) {
    if (!this._started) return console.log('[Route] Cannot go(' + path + ',...) before router is started.');
    if (path.indexOf(this.baseUrl) == 0) path = path.substr(this.baseUrl.length);

    if (replace) {
      if (path.indexOf(this.basePath) != 0) path = this.basePath + path;
      state = state ? state : this.ctx.state || {};
      this.ctx.state = state;
      this._history.replaceState(this.ctx.state, this.title, path);
      this._page.show(this._pathWithoutPrefix(path), state || {}, true, false);
    }
    else {
      this._page.show(this._pathWithoutPrefix(path), state || {}, true, true);
    }
  }

  param(name, def = '') {
    const params = this.ctx.params;
    if (params.hasOwnProperty(name)) return params[name];

    const query = this.query;
    if (query.hasOwnProperty(name)) return query[name];

    return def;
  }

  render() {
    this._page.start();
    this._started = true;
  }

  subscribe(cb) {
    cb(this);
    return this.on('update', cb);
  }

  update(params) {
    if (params.baseUrl) {
      params.baseUrl = params.baseUrl.replace(/\/+$/, '');
      this._basePath = new URL(params.baseUrl).pathname.replace(/\/+$/, '');
    }
    if (params.title) {
      this.ctx.title = params.title;
    }

    return super.update(params);
  }

  urlFor(url) {
    return url.match(/^\w+:/) ? url : url.match(/^#/) ? url : this.basePath + url;
  }

  urlToForm(formEl) {
    Object.keys(this.query).forEach(name => {
      const val = this.query[name];
      const inputEl = formEl[name];
      if (!inputEl || !inputEl.tagName) return;

      if (inputEl.type == 'checkbox') {
        inputEl.checked = val ? true : false;
      }
      else {
        inputEl.value = val;
      }

      if (inputEl.syncValue) inputEl.syncValue();
    });
  }

  _pathWithoutPrefix(path) {
    return path.indexOf(this.basePath) == 0 ? path.substr(this.basePath.length) : path;
  }
}

export const route = new Route();
