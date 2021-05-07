import Reactive from '../js/Reactive';
import qs from 'qs';
import {activeMenu} from './writable';
import {closestEl, is} from '../js/util';

export default class Route extends Reactive {
  constructor() {
    super();

    this.prop('ro', 'basePath', () => this._basePath);
    this.prop('ro', 'hash', () => (this._location.hash || '').replace(/^#/, ''));
    this.prop('ro', 'path', () => this._path);
    this.prop('ro', 'pathParts', () => this._pathParts);
    this.prop('ro', 'query', () => this._query);
    this.prop('rw', 'baseUrl', '');

    this._onClick = this._onClick.bind(this);
    this._onLocationChange = this._onLocationChange.bind(this);
    window.addEventListener('click', this._onClick);
    window.addEventListener('popstate', this._onLocationChange);

    this._history = window.history;
    this._location = window.location;
    this._basePath = '';
    this._path = '/';
    this._pathParts = [];
    this._query = {};
  }

  conversationPath(params) {
    const path = ['', 'chat'];
    if (params.connection_id) path.push(params.connection_id);
    if (params.conversation_id) path.push(params.conversation_id);

    return path.map(p => encodeURIComponent(p)).join('/');
  }

  go(path, params = {}) {
    if (path.indexOf(this.baseUrl) == 0) path = path.substr(this.baseUrl.length);
    const url = this.baseUrl + path;
    if (url == this._location.href) return this;
    this._history[params.replace ? 'replaceState' : 'pushState']({}, document.title, url);
    if (!params.replace) activeMenu.set('');
    this.update({path: true})._onLocationChange({});
  }

  param(name, def = '') {
    const query = this.query;
    if (query.hasOwnProperty(name)) return query[name];
    return def;
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

    super.update(params);
    if (params.baseUrl) this._onLocationChange();
    return this;
  }

  urlFor(url, query = {}) {
    const base = url.match(/^\w+:/) ? url : url.match(/^#/) ? url : this.basePath + url;
    const queryString = Object.keys(query).sort().filter(k => is.defined(query[k])).map(k => k + '=' + encodeURIComponent(query[k])).join('&');
    return base + (queryString ? '?' + queryString : '');
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
    if (href.indexOf('#') == 0) href = this.path + href;
    if (href.indexOf(this.baseUrl) == 0) href = href.substr(this.baseUrl.length);
    if (href.indexOf(this.basePath) == 0) href = href.substr(this.basePath.length);
    if (href.indexOf('/') == 0) {
      this.go(href, {}, linkEl.hasAttribute('replace'));
      e.preventDefault();
    }
  }

  _onLocationChange(e) {
    activeMenu.set('');
    const abs = this._location.href;
    const pathname = abs.substr(this.baseUrl.length);
    const url = pathname.split('#')[0].split('?');
    this._query = url.length == 2 ? qs.parse(url.pop()) : {};
    this._path = url[0];
    this._pathParts = url[0].replace(/^\//, '').split('/').map(decodeURIComponent);
    this.update({path: true});
  }
}

export const route = new Route();
