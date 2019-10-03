export default class Reactive {
  constructor() {
    this._syncWithLocalStorage = {};
    this._reactive = {};
    this._on = {loaded: [], message: [], update: []};
  }

  emit(event, params) {
    this._on[event].forEach(cb => cb(params));
  }

  on(event, cb) {
    const p = cb ? null : new Promise(resolve => { cb = resolve });
    const unsubscribe = () => this._on[event].filter(i => (i != cb));
    this._on[event].push(cb);
    return p ? p.finally(unsubscribe) : unsubscribe;
  }

  // This is used by https://svelte.dev/docs#svelte_store
  subscribe(cb) {
    this._on.update.push(cb);
    cb(this);
    return () => this._on.update.filter(i => (i != cb));
  }

  update(params) {
    Object.keys(params).forEach(name => {
      if (this._reactive.hasOwnProperty(name)) this._reactive[name] = params[name];
      if (this._syncWithLocalStorage[name]) localStorage.setItem(name, JSON.stringify(this._reactive[name]));
    });

    if (!this._notifyTid) this._notifyTid = setTimeout(this._notify.bind(this), 0);
    return this;
  }

  _localStorageAttr(name, val) {
    this._updateableAttr(name, val);
    this._syncWithLocalStorage[name] = true;
    if (localStorage.hasOwnProperty(name)) this._reactive[name] = JSON.parse(localStorage.getItem(name));
  }

  _notify() {
    delete this._notifyTid;
    this._on.update.forEach(cb => cb(this));
    if (this.status != 'loading' && this.status != 'pending') this.emit('loaded', this);
  }

  _readOnlyAttr(name, val) {
    if (val === undefined) throw 'Read-only attribute "' + name + '" cannot be undefined for ' + this.constructor.name;
    const descriptor = typeof val == 'function' ? {get: val} : {value: val, writable: false};
    Object.defineProperty(this, name, descriptor);
  }

  _updateableAttr(name, val) {
    this._reactive[name] = val;
    Object.defineProperty(this, name, {get: () => this._reactive[name]});
  }
}
