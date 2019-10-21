export default class Reactive {
  constructor() {
    this._on = {};
    this._proxyTo = {};
    this._reactiveAttr = {};
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

      if (this._proxyTo[name]) {
        this[this._proxyTo[name]].update({[name]: params[name]});
      }
      else if (this._reactiveAttr.hasOwnProperty(name)) {
        if (this._reactiveAttr[name] !== params[name]) updated++;
        this._reactiveAttr[name] = params[name];
      }
      else if (!this.hasOwnProperty(name)) {
        throw 'Not an updateable attribute: ' + name;
      }

      if (this._syncWithLocalStorage[name]) {
        this._localStorage(name, this._reactiveAttr[name]);
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

  _localStorage(name, val) {
    name = 'convos:' + name;
    return arguments.length == 2 ? localStorage.setItem(name, JSON.stringify(val)) : localStorage.getItem(name);
  }

  _localStorageAttr(name, val) {
    const inStorage = localStorage.hasOwnProperty(name);
    this._updateableAttr(name, inStorage ? this._localStorage(name) : val);
    this._syncWithLocalStorage[name] = true;
    if (!inStorage) this._localStorage(name, val);
  }

  _proxyAttr(name, to) {
    // TODO: Add support for _readOnlyAttr
    this._proxyTo[name] = to;
    Object.defineProperty(this, name, {get: () => this[to]._reactiveAttr[name]});
  }

  _readOnlyAttr(name, val) {
    if (val === undefined) throw 'Read-only attribute "' + name + '" cannot be undefined for ' + this.constructor.name;
    const descriptor = typeof val == 'function' ? {get: val} : {value: val, writable: false};
    Object.defineProperty(this, name, descriptor);
  }

  _updateableAttr(name, val) {
    this._reactiveAttr[name] = val;
    Object.defineProperty(this, name, {get: () => this._reactiveAttr[name]});
  }
}
