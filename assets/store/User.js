import Connection from './Connection';
import Dialog from './Dialog';
import Events from '../js/Events';
import Operation from './Operation';
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
    this._readOnlyAttr('events', new Events({user: this}));

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
    conn.on('message', params => this.send({source: 'connection', ...params}));
    this.update({connections: this.connections.concat(conn).sort(sortByName)});
    return conn;
  }

  findDialog(params) {
    if (!params.dialog_id) return this.connections.filter(conn => conn.connection_id == params.connection_id)[0];
    const conn = this.findDialog({connection_id: params.connection_id});
    return conn && conn.findDialog(params);
  }

  isDialogOperator(params) {
    // TODO: No idea if this actually works
    const conn = this.findDialog({connection_id: params.connection_id});
    const dialog = this.findDialog(params);
    if (!conn || !dialog) return false;
    const myself = dialog.findParticipants({nick: conn.nick})[0];
    return myself && myself.mode && myself.mode.indexOf('o') != -1;
  }

  async load() {
    if (this.is('loading')) await this.on('loaded');
    if (this.is('success')) return this;
    this.update({status: 'loading'});
    await this.perform();
    if (this.email) await this.send({method: 'ping'});
    return this;
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
    if (msg.method == 'ping') return this._ping();
    if (!msg.id) msg.id = (msg.source || 'user') + (++msgId);
    if (msg.dialog) ['connection_id', 'dialog_id'].forEach(k => { msg[k] = msg.dialog[k] });
    delete msg.dialog;
    ws.send(JSON.stringify(msg));
  }

  _ping() {
    if (this.ws && this.ws.readyState == 1) this.ws.send('{"method":"ping"}');
  }

  async _ws() {
    if (this._wsPromise) return this._wsPromise;
    if (this._wsReconnectTid) clearTimeout(this._wsReconnectTid);

    const ws = new WebSocket(this.wsUrl);
    if (!this._wsTid) this._wsTid = setInterval(() => this._ping(), 15000);

    let handled = false;
    const p = new Promise((resolve, reject) => {
      ws.onopen = () => {
        if (![handled, (handled = true)][0]) resolve((this.ws = ws));
      };

      ws.onclose = (e) => {
        delete this._wsPromise;
        this._wsReconnectTid = setTimeout(() => this._ws(), 20000);
        this.connections.forEach(conn => conn.update({frozen: 'Unreachable.'}));
        this.update({});
        if (![handled, (handled = true)][0]) reject(e);
      };

      ws.onerror = (e) => reject(e); // TODO
      ws.onmessage = (e) => this.events.dispatch(JSON.parse(e.data));
    });

    return (this._wsPromise = p);
  }
}
