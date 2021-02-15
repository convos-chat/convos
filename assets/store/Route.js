import Reactive from '../js/Reactive';
import qs from 'qs';
import {closestEl, isType} from '../js/util';

export default class Route extends Reactive {
  constructor() {
    super();

    this.prop('ro', 'basePath', () => this._basePath);
    this.prop('ro', 'hash', () => (this._location.hash || '').replace(/^#/, ''));
    this.prop('ro', 'path', () => this._path);
    this.prop('ro', 'params', () => this._params);
    this.prop('ro', 'query', () => this._query);

    this.prop('rw', 'baseUrl', '');
    this.prop('rw', 'component', null);
    this.prop('rw', 'match', '');
    this.prop('rw', 'requireLogin', false);
    this.prop('rw', 'state', {});
    this.prop('rw', 'title', document.title || '');

    this.prop('persist', 'lastUrl', '');

    this._history = window.history;
    this._location = window.location;
    this._onClick = this._onClick.bind(this);
    this._onpopstate = this._onpopstate.bind(this);

    this._basePath = '';
    this._params = {};
    this._path = '/';
    this._query = {};
    this._routes = [];
  }

  conversationPath(params) {
    const path = ['', 'chat'];
    if (params.connection_id) path.push(params.connection_id);
    if (params.conversation_id) path.push(params.conversation_id);

    return path.map(p => encodeURIComponent(p)).join('/');
  }

  go(path, state = {}, replace = false) {
    if (state.replace) [replace, state] = [true, this.state];
    if (path.indexOf(this.baseUrl) == 0) path = path.substr(this.baseUrl.length);
    const url = this.baseUrl + path;
    if (url == this._location.href) return this;
    this._history[replace ? 'replaceState' : 'pushState'](state, this.title, url);
    this.render(url, state);
  }

  param(name, def = '') {
    const params = this.params;
    if (params.hasOwnProperty(name)) return params[name];

    const query = this.query;
    if (query.hasOwnProperty(name)) return query[name];

    return def;
  }

  render(abs, state) {
    if (!this._started) {
      window.addEventListener('click', this._onClick);
      window.addEventListener('popstate', this._onpopstate);
      this._started = true;
    }

    if (!abs) abs = this._location.href;
    if (!state) state = this.state;

    this._urlToProps(abs);
    this._params = {};
    for (let ri = 0; ri < this._routes.length; ri++) {
      const route = this._routes[ri];
      const m = this._path.match(route.re);
      if (!m) continue;

      for (let pi = 0; pi < route.names.length; pi++) {
        this._params[route.names[pi]] = decodeURIComponent(m[pi + 1]);
      }

      route.cb(this);

      const e = document.createEvent('CustomEvent');
      e.initCustomEvent('routerender', false, false, {});
      setTimeout(() => document.dispatchEvent(e), 1);

      return this;
    }

    console.log({abs, routes: this._routes});
    throw '[Route] No route for "' + abs + '".';
  }

  subscribe(cb) {
    cb(this);
    return this.on('update', cb);
  }

  to(path, cb) {
    const names = [];
    const parts = [];

    path.split('/').forEach((p, i) => {
      let re = p;

      if (p.indexOf('*') == 0) {
        re = '(.*)';
        names.push(String(p.slice(1) || i));
      }
      else if (p.indexOf(':') == 0) {
        re = '([^/]+)';
        names.push(String(p.slice(1) || i));
      }

      parts.push(re);
    });

    this._routes.push({cb, names, path, re: new RegExp('^' + parts.join('/') + '$')});
  }

  update(params) {
    if (params.baseUrl) {
      params.baseUrl = params.baseUrl.replace(/\/+$/, '');
      this._basePath = new URL(params.baseUrl).pathname.replace(/\/+$/, '');
    }

    super.update(params);
    if (params.baseUrl) this._urlToProps(location.href);
    return this;
  }

  urlFor(url, query = {}) {
    const base = url.match(/^\w+:/) ? url : url.match(/^#/) ? url : this.basePath + url;
    const queryString = Object.keys(query).sort().filter(k => !isType(query[k], 'undef')).map(k => k + '=' + encodeURIComponent(query[k])).join('&');
    return base + (queryString ? '?' + queryString : '');
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

  wsUrlFor(url) {
    const wsUrl = url.match(/^\w+:/) ? url : this.baseUrl + url;
    return wsUrl.replace(/^http/, 'ws');
  }

  _onClick(e) {
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.defaultPrevented) return;

    const linkEl = e.target && e.target.closest('a');
    if (!linkEl || !linkEl.href) return;

    if (linkEl.target == '_self') {
      let href = linkEl.href.indexOf('/') == 0 ? this.baseUrl + linkEl.href : linkEl.href;
      if (href == location.href) return location.reload();
    }

    if (linkEl.hasAttribute('download') || linkEl.hasAttribute('target')) return;

    let href = linkEl.getAttribute('href') || '';
    if (href.indexOf(this.baseUrl) == 0) href = href.substr(this.baseUrl.length);
    if (href.indexOf(this.basePath) == 0) href = href.substr(this.basePath.length);
    if (href.indexOf('/') == 0) {
      this.go(href, {}, linkEl.hasAttribute('replace'));
      e.preventDefault();
    }
  }

  _onpopstate(e) {
    this.render(this._location.href, e.state);
  }

  _pathWithoutPrefix(path) {
    return path.indexOf(this.basePath) == 0 ? path.substr(this.basePath.length) : path;
  }

  _urlToProps(abs) {
    const pathname = abs.substr(this.baseUrl.length);
    const url = pathname.split('#')[0].split('?');
    this._query = url.length == 2 ? qs.parse(url.pop()) : {};
    this._path = url[0];
  }
}

export const route = new Route();
