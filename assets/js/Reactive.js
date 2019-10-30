/**
 * Reactive is a class that can be useful for objects that you want to observe.
 * It also contains some helper methods to define properties.
 *
 * @exports Reactive
 * @class Reactive
 * @see Dialog
 * @see EmbedMaker
 * @see Events
 * @see Operation
 * @see User
 */

export default class Reactive {
  constructor() {
    this._on = {};
    this._proxyTo = {};
    this._reactiveProp = {};
    this._syncWithLocalStorage = {};
  }

  /**
   * emit() is used to notify listeners about a change.
   *
   * @memberof Reactive
   * @param {String} event The name of the event to emit.
   * @param {Any} params Any data that will be passed on to the listeners.
   */
  emit(event, params) {
    const subscribers = this._on[event];
    if (!subscribers) return this;
    for (let i = 0; i < subscribers.length; i++) subscribers[i][0](params);
    return this;
  }

  /**
   * on() is used by listeners to listen for an event to be emitted.
   *
   * @memberof Reactive
   * @param {String} event The name of the event to listen to.
   * @param {Function} cb A function to be called when an event is emitted.
   */
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

  /**
   * prop() can be used to define a new property.
   *
   * The following types are allowed:
   *
   * 1. "persist" is a property that will be stored in the browser's localStorage.
   *    It can be changed by calling update().
   * 2. "proxy" is a property that belongs to a child object.
   * 3. "ro" is a property that cannot be changed.
   * 4. "rw" is a property that can be changed by the "update()" method.
   *
   * The code below cannot be used to update any prop() property. A change must
   * go through update().
   *
   *     this.some_property = 'new value';
   *
   * @memberof Reactive
   * @param {String} type either "persist", "proxy", "ro" or "rw".
   * @param {String} name The name of the property
   * @param {Any} val Either a function or default value.
   */
  prop(type, name, val) {
    switch (type) {
      case 'persist': return this._localStorageProp(name, val);
      case 'proxy': return this._proxyProp(name, val);
      case 'ro': return this._readOnlyProp(name, val);
      case 'rw': return this._updateableProp(name, val);
    }

    throw 'Unknown prop type "' + type + '" for prop "' + name + '".';
  }

  /**
   * subscribe() is a special case of `on()` to listen for "update" events.
   * This method exists because it is used by
   * [Svelte stores](https://svelte.dev/docs#svelte_store).
   *
   * The function passed to this method will also be called right away, with
   * the current object as parameter.
   *
   * @memberof Reactive
   * @param {Function} cb A function to be called when the "update" event is emitted.
   */
  subscribe(cb) {
    cb(this);
    return this.on('update', cb);
  }

  /**
   * update() can be used to change the properties defined by prop(). This
   * method will asynchronously emit the "update" event once all properties
   * have been updated.
   *
   * Any key in "params" that does not map to a defined prop() will be ignored.
   *
   * @memberof Reactive
   * @param {Object} params A map between property name and value.
   */
  update(params) {
    const paramNames = Object.keys(params);
    let updated = paramNames.length;

    for (let i = 0; i < paramNames.length; i++) {
      const name = paramNames[i];

      if (this._proxyTo[name]) {
        this[this._proxyTo[name]].update({[name]: params[name]});
      }
      else if (this._reactiveProp.hasOwnProperty(name)) {
        if (this._reactiveProp[name] === params[name]) updated--;
        this._reactiveProp[name] = params[name];
      }

      if (this._syncWithLocalStorage[name]) {
        this._localStorage(name, this._reactiveProp[name]);
      }
    }

    if (updated && !this._updatedTid) {
      //console.log({type: 'update', id: this.name || this.email, paramNames: paramNames.join(','), updated});
      this._updatedTid = setTimeout(() => { delete this._updatedTid; this.emit('update', this) }, 1);
    }

    return this;
  }

  _localStorage(name, val) {
    name = 'convos:' + name;
    if (arguments.length == 2) return localStorage.setItem(name, JSON.stringify(val));
    return localStorage.hasOwnProperty(name) ? JSON.parse(localStorage.getItem(name)) : undefined;
  }

  _localStorageProp(name, val) {
    const fromStorage = this._localStorage(name);
    this._updateableProp(name, typeof fromStorage == 'undefined' ? val : fromStorage);
    this._syncWithLocalStorage[name] = true;
    if (typeof fromStorage == 'undefined') this._localStorage(name, val);
  }

  _proxyProp(name, to) {
    this._proxyTo[name] = to;
    Object.defineProperty(this, name, {get: () => this[to]._reactiveProp[name]});
  }

  _readOnlyProp(name, val) {
    if (val === undefined) throw 'Read-only attribute "' + name + '" cannot be undefined for ' + this.constructor.name;
    const descriptor = typeof val == 'function' ? {get: val} : {value: val, writable: false};
    Object.defineProperty(this, name, descriptor);
  }

  _updateableProp(name, val) {
    this._reactiveProp[name] = val;
    Object.defineProperty(this, name, {get: () => this._reactiveProp[name]});
  }
}