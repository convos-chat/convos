import Connection from './Connection';
import Dialog from './Dialog';
import Operation from './Operation';
import eventDispatcher from '../js/eventDispatcher';
import eventMessages from '../js/eventMessages';
import {sortByName} from '../js/util';

let msgId = 0;

export default class User extends Operation {
  constructor(params) {
    super({
      api: params.api,
      defaultParams: {connections: true, dialogs: true, notifications: true},
      id: 'getUser',
    });

    this._readOnlyAttr('email', () => this.res.body.email || '');
    this._readOnlyAttr('notifications', new Dialog({api: this.api, name: 'Notifications'}));
    this._readOnlyAttr('wsUrl', params.wsUrl);

    this._updateableAttr('connections', []);
    this._updateableAttr('enableNotifications', Notification.permission);
    this._updateableAttr('expandUrlToMedia', true);

    // Add operations that will affect the "User" object
    // TODO: Make operations bubble into the User object. Require changes in App.svelte
    this._readOnlyAttr('login', this.api.operation('loginUser'));
    this._readOnlyAttr('logout', this.api.operation('logoutUser'));
    this._readOnlyAttr('readNotifications', this.api.operation('readNotifications'));
    this._readOnlyAttr('register', this.api.operation('registerUser'));
  }

  ensureDialog(params) {
    // Ensure channel or private dialog
    if (params.dialog_id) {
      const dialog = this.ensureDialog({connection_id: params.connection_id}).ensureDialog(params);
      this.update({});
      return dialog;
    }

    // Find connection
    let conn = this.findDialog(params);
    if (conn) {
      this.update({});
      return conn.update(params);
    }

    // Create connection
    conn = new Connection({...params, api: this.api});
    this.update({connections: this.connections.concat(conn).sort(sortByName)});
    return conn;
  }

  findDialog(params) {
    if (!params.dialog_id) return this.connections.filter(conn => conn.connection_id == params.connection_id)[0];
    const conn = this.findDialog({connection_id: params.connection_id});
    return conn && conn.findDialog(params);
  }

  async load() {
    await this.perform();
    if (this.email) await this.send({});
  }

  parse(res, body = res.body) {
    Operation.prototype.parse.call(this, res, body);
    if (body.notifications) this.notifications.update({messages: body.notifications}); // Need to be done before this.update()
    if (body.connections) body.connections.forEach(c => this.ensureDialog(c));
    if (body.dialogs) body.dialogs.forEach(d => this.ensureDialog(d));
    return this;
  }

  removeDialog(params) {
    if (params.dialog_id) {
      const conn = this.findDialog({connection_id: params.connection_id});
      if (conn) conn.removeDialog(params);
      this.update({});
    }
    else {
      this.update({connections: this.connections.filter(conn => conn.connection_id != params.connection_id)});
    }
  }

  async send(msg) {
    const ws = await this._ws();
    if (!msg.id) msg.id = (++msgId);
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
        this.connections.forEach(conn => { conn.status = 'Unreachable.' });
        this.update({});
        if (![handled, (handled = true)][0]) reject(e);
      };

      ws.onerror = (e) => reject(e); // TODO
      ws.onmessage = (e) => {
        const event = JSON.parse(e.data);
        eventDispatcher(event, {user: this});
        eventMessages(event, {user: this});
      };
    });
  }
}