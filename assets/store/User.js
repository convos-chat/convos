import Connection from './Connection';
import Dialog from './Dialog';
import Operation from './Operation';
import {get, writable} from 'svelte/store';
import {ro, sortByName} from '../js/util';

export default class User extends Operation {
  constructor(params) {
    super({
      api: params.api,
      defaultParams: {connections: true, dialogs: true, notifications: true},
      id: 'getUser',
    });

    this.msgId = 0;
    ro(this, 'email', () => this.res.body.email || '');
    ro(this, 'wsUrl', params.wsUrl);

    // "User" is a store, but it has sub svelte stores that can be watched
    ro(this, 'connections', writable([]));
    ro(this, 'enableNotifications', writable(Notification.permission));
    ro(this, 'expandUrlToMedia', writable(false));
    ro(this, 'notifications', new Dialog({api: this.api, name: 'Notifications'}));

    // Add operations that will affect the "User" object
    // TODO: Make operations bubble into the User object. Require changes in App.svelte
    ro(this, 'login', this.api.operation('loginUser'));
    ro(this, 'logout', this.api.operation('logoutUser'));
    ro(this, 'readNotifications', this.api.operation('readNotifications'));
    ro(this, 'register', this.api.operation('registerUser'));
  }

  ensureDialog(params) {
    // Ensure channel or private conversation
    if (params.dialog_id) return this.ensureDialog({connection_id: params.connection_id}).ensureDialog(params);

    // Find connection
    let conn = this.findDialog(params);
    if (conn) return conn.update(params);

    // Create connection
    conn = new Connection({...params, api: this.api});
    this.connections.set(get(this.connections).concat(conn).sort(sortByName));
    return conn;
  }

  findDialog(params) {
    if (!params.dialog_id) return get(this.connections).filter(conn => conn.id == params.connection_id)[0];
    const conn = this.findDialog({connection_id: params.connection_id});
    return conn && conn.findDialog(params)
  }

  async load() {
    await this.perform();
    if (this.email) await this.send({});
  }

  parse(res, body = res.body) {
    Operation.prototype.parse.call(this, res, body);
    if (body.connections) body.connections.forEach(c => this.ensureDialog(c));
    if (body.dialogs) body.dialogs.forEach(d => this.ensureDialog(d));
    return this;
  }

  removeDialog(params) {
    if (params.dialog_id) {
      const conn = this.findDialog({connection_id: params.connection_id});
      if (conn) conn.removeDialog(params);
    }
    else {
      this.connections.set(get(this.connections).filter(conn => conn.id != params.connection_id));
    }
  }

  async send(msg) {
    const ws = await this._ws();
    if (!msg.id) msg.id = (++this.msgId);
    ws.send(JSON.stringify(msg));
  }

  async _ws() {
    if (this.ws && [0, 1].indexOf(this.ws.readyState) != -1) return this.ws; // [CONNECTING, OPEN, CLOSING, CLOSED]
    if (this._wsReconnectTid) clearTimeout(this._wsReconnectTid);

    const ws = new WebSocket(this.wsUrl);
    if (!this.ws) this.ws = ws;

    let handled = false;
    return new Promise((resolve, reject) => {
      ws.onopen = () => {
        if (![handled, (handled = true)][0]) resolve((this.ws = ws));
      };

      ws.onclose = (e) => {
        this._wsReconnectTid = setTimeout(() => this._ws(), 1000);
        get(this.connections).forEach(conn => { conn.status = 'Unreachable.' });
        if (![handled, (handled = true)][0]) reject(e);
      };

      ws.onerror = (e) => reject(e); // TODO
      ws.onmessage = (e) => {
        const data = JSON.parse(e.data);

        if (data.event == 'message') {
          this.ensureDialog(data).messages.add(data);
        }

        console.log('TODO: Handle WebSocket message', data);
      };
    });
  }
}