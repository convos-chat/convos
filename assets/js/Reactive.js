export default class Reactive {
  constructor() {
    this._on = {};
    this._reactive = {};
    this._syncWithLocalStorage = {};
  }

  emit(event, params) {
    const subscribers = this._on[event];
    if (!subscribers) return this;
    for (let i = 0; i < subscribers.length; i++) subscribers[i][0](params);
    return this;
  }

  on(event, cb) {
    const p = cb ? null : new Promise(resolve => { cb = resolve });
    const subscribers = this._on[event] || (this._on[event] = []);
    const subscriber = [cb]; // Make sure each element is unique
    subscribers.push(subscriber);

    const unsubscribe = () => {
      const index = subscribers.indexOf(subscriber);
      if (index != -1) subscribers.splice(index, 1);
    };

    return p ? p.finally(unsubscribe) : unsubscribe;
  }

  // This is used by https://svelte.dev/docs#svelte_store
  subscribe(cb) {
    cb(this);
    return this.on('update', cb);
  }

  update(params) {
    let paramNames = Object.keys(params);
    let updated = 0;

    for (let i = 0; i < paramNames.length; i++) {
      const name = paramNames[i];

      if (this._reactive.hasOwnProperty(name) && this._reactive[name] !== params[name]) {
        this._reactive[name] = params[name];
        updated++;
      }

      if (this._syncWithLocalStorage[name]) {
        localStorage.setItem(name, JSON.stringify(this._reactive[name]));
      }
    }

    if (!this._updatedTid && updated || paramNames.length == 0) {
      this._updatedTid = setTimeout(() => {
        delete this._updatedTid;
        this.emit('update', this);
      }, 1);
    }

    return this;
  }

  _localStorageAttr(name, val) {
    this._updateableAttr(name, val);
    this._syncWithLocalStorage[name] = true;
    if (localStorage.hasOwnProperty(name)) this._reactive[name] = JSON.parse(localStorage.getItem(name));
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
