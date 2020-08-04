/**
 * Socket is a wrapper around the standard WebSocket.
 *
 * @module Socket
 * @exports socket
 */

import Reactive from './Reactive';

/**
 * socket() can be used to create global socket objects.
 *
 * @param {String} id A global identifier for this Socket object.
 * @param {Object} msg A message to send to the server.
 * @returns {Object} A Socket object if no "msg" is specified.
 * @returns {Promise} A promise if "msg" is specified.
 */
export const socket = (id, msg) => {
  const singleton = socket.singletons[id] || (socket.singletons[id] = new Socket());
  return msg ? singleton.send(msg) : singleton;
};

socket.singletons = {};

const readyStateHuman = [];
readyStateHuman[WebSocket.CONNECTING] = 'connecting';
readyStateHuman[WebSocket.OPEN] = 'open';
readyStateHuman[WebSocket.CLOSING] = 'closing';
readyStateHuman[WebSocket.CLOSED] = 'closed';

export default class Socket extends Reactive {
  constructor() {
    super();

    this.prop('ro', 'readyState', () => this.ws.readyState);
    this.prop('ro', 'readyStateHuman', () => readyStateHuman[this.ws.readyState]);
    this.prop('rw', 'error', '');
    this.prop('rw', 'keepaliveInterval', 10000);
    this.prop('rw', 'keepaliveMessage', {});
    this.prop('rw', 'online', true);
    this.prop('rw', 'url', '');

    this.debug = true; // Setting this to true for now, since it might help debugging the "close" issue
    this.id = 0;
    this.queue = [];
    this.keepClosed = true;
    this.waiting = {};
    this._resetWebSocket();

    this._onOffline = this._onOffline.bind(this);
    this._onOnline = this._onOnline.bind(this);
    window.addEventListener('offline', this._onOffline);
    window.addEventListener('online', this._onOnline);
  }

  /**
   * Used to close the WebSocket connection, clear keepalive and reconnect
   * timers and make sure that the WebSocket stays closed.
   *
   * @memberof Socket
   * @param {Number} code Default to 1000.
   * @param {String} reason Default to no reason.
   * @returns {Object} Returns invocant
   */
  close(code, reason) {
    if (typeof code != 'number') [code, reason] = [1000, code];
    if (this.ws.close) this.ws.close(code, reason);
    this.keepClosed = true;
    this._clearTimers();
    this._resetWebSocket();
    return this;
  }

  /**
   * deflateMessage() takes a data structure and converts it into a string that
   * will be passed over the WebSocket.
   *
   * @example
   * const api = new Api()
   * api.deflateMessage = (msg) => JSON.stringify(msg);
   *
   * @memberof Socket
   * @param {Object} msg A message object to serialize.
   * @returns {String}
   */
  deflateMessage(msg) {
    return JSON.stringify(msg);
  }

  /**
   * inflateMessage() takes a string and converts it into a data structure.
   *
   * @example
   * const api = new Api()
   * api.inflateMessage = (str) => JSON.parse(str);
   *
   * @memberof Socket
   * @param {String} str A message from the WebSocket
   * @returns {Object}
   */
  inflateMessage(str) {
    return JSON.parse(str);
  }

  /**
   * is() can be used to check the state.
   *
   * @example
   * api.is('connecting'); // Checks if the WebSocket is connecting
   * api.is('open');       // Checks if the WebSocket is open
   * api.is('closing');    // Checks if the WebSocket is closing
   * api.is('closed');     // Checks if the WebSocket is closed
   * api.is('online');     // Checks if the browser is connected to the internet
   * api.is('offline');    // Checks if the browser is not connected to the internet
   *
   * @memberof Socket
   * @param {Sring} state See the examples above
   * @returns {Boolean} True if the object is in the given state
   */
  is(state) {
    if (this.ws.readyState == WebSocket[state.toUpperCase()]) return true;
    if (state == 'online') return this.online;
    if (state == 'offline') return !this.online;
    return false;
  }

  /**
   * Used to manually open a WebSocket connection. This method will automatically
   * get called by send().
   *
   * @memberof Socket
   * @returns {Object} The invocant
   */
  open() {
    if (this.ws.close) return this;

    try {
      if (!this.url) throw '[Socket] Can\'t open connection without URL.';
      this.ws = new WebSocket(this.url);
      this.ws.onclose = (e) => this._onClose(e);
      this.ws.onerror = (e) => this._onError(e);
      this.ws.onmessage = (e) => this._onMessage(e);
      this.ws.onopen = (e) => this._onOpen(e);
      this.update({error: ''});
    } catch(err) {
      this._onError(err.message ? err : {message: String(err)});
    }

    this._clearTimers();
    this._keepalive();
    this.keepClosed = false;
    this.update({readyState: true});

    return this;
  }

  /**
   * reconnectIn() can be used to calculate when to reconnect when a WebSocket
   * connection is lost.
   *
   * @memberof Socket
   * @param {Event} e Normally a CloseEvent.
   * @returns {Number} Number of milliseconds to reconnect.
   * @returns {Boolean} False to cancel the reconnect.
   * @returns {Boolean} True to reconnect now.
   */
  reconnectIn(e) {
    if (e.code === 1008 || e.code === 1011) return false;
    return 1000;
  }

  /**
   * Used to send a message to the server. Will also open the WebSocket, unless
   * already connected.
   *
   * @param {Object} msg A message to send to the server.
   * @returns {Promise} A promise that will get resolved when the response comes.
   */
  send(msg) {
    const id = String(++this.id);
    this.queue.push({...msg, id});
    this.open();
    this._dequeue();
    return this.on('message_' + id);
  }

  _clearTimers() {
    if (this.keepaliveTid) clearTimeout(this.keepaliveTid);
    delete this.keepaliveTid;
    if (this.reconnectTid) clearTimeout(this.reconnectTid);
    delete this.reconnectTid;
  }

  _dequeue() {
    const queue = this.queue;
    while (queue.length) {
      if (this.ws.readyState != WebSocket.OPEN) return;
      const msg = queue.shift();
      this.ws.send(this.deflateMessage(msg));
      this.waiting[msg.id] = msg;
    }
  }

  _keepalive() {
    if (!this.keepaliveTid) return (this.keepaliveTid = setInterval(() => this._keepalive(), this.keepaliveInterval));
    if (this.ws.readyState == WebSocket.OPEN) this.ws.send(this.deflateMessage(this.keepaliveMessage));
  }

  _onClose(e) {
    if (this.debug) console.log('[Socket:close]', new Time().toISOString(), e);
    this._clearTimers();
    this._resetWebSocket();
    this.update({readyState: true});

    const delay = this.reconnectIn(e);
    if (delay === true) return this.open();
    if (typeof delay != 'number') return (this.keepClosed = true);
    this.reconnectTid = setTimeout(() => this.open(), delay);
  }

  _onError(e) {
    if (this.debug) console.log('[Socket:error]', new Time().toISOString(), e);
    this.update({error: e.message || String(e)});
  }

  _onMessage(e) {
    const msg = this.inflateMessage(e.data);

    if (msg.id) {
      this.emit('message_' + msg.id, msg);
      delete this.waiting[msg.id];
    }

    this.emit('message', msg);

    if (!msg.errors || msg.id) return;
    Object.keys(this.waiting).forEach(id => this.emit('message_' + id, msg));
    this.waiting = {};
  }

  _onOffline(e) {
    if (this.debug) console.log('[Socket:offline]', new Time().toISOString(), e);
    this.update({online: false});
    this._clearTimers();
  }

  _onOnline(e) {
    if (this.debug) console.log('[Socket:online]', new Time().toISOString(), e);
    this.update({online: true});
    if (this.keepClosed) return;
    this._keepalive();
    this.open();
  }

  _onOpen(e) {
    if (this.debug) console.log('[Socket:open]', new Time().toISOString(), e);
    this.update({error: '', readyState: true});
    this._dequeue();
  }

  _resetWebSocket() {
    this.ws = {readyState: WebSocket.CLOSED};
  }
}
