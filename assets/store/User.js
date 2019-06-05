import ConnURL from '../js/ConnURL';
import Messages from './Messages';
import Operation from '../store/Operation';
import {writable} from 'svelte/store';

const byName = (a, b) => a.name.localeCompare(b.name);

export default class User extends Operation {
  constructor(params) {
    super({
      api: params.api,
      defaultParams: {connections: true, dialogs: true, notifications: true},
      id: 'getUser',
    });

    // Define proxy properties into this.res.body
    ['connections', 'dialogs'].forEach(name => {
      Object.defineProperty(this, name, {get: () => { return this.res.body[name] || [] }});
    });

    Object.defineProperty(this, 'email', {get: () => this.res.body.email || ''});

    // Add operations that will affect the "User" object
    // TODO: Make operations bubble into the User object. Require changes in App.svelte
    this.login = this.api.operation('loginUser');
    this.logout = this.api.operation('logoutUser');
    this.register = this.api.operation('registerUser');
    this.readNotifications = this.api.operation('readNotifications');

    this.msgId = 0;
    this.notifications = this._messages({});
    this.notifications.messages = this.res.body.notifications || [];
    this.wsUrl = params.wsUrl;

    // "User" is a store, but it has sub svelte stores that can be watched
    this.connectionsWithChannels = writable([]);
    this.enableNotifications = writable(Notification.permission);
    this.expandUrlToMedia = writable(false);
  }

  ensureConnection(obj, params = {}) {
    obj.url = typeof obj.url == 'string' ? new ConnURL(obj.url) : obj.url;
    obj.channels = [];
    obj.private = [];
    obj.messages = this._messages(obj);
    Object.defineProperty(obj, 'id', {get: () => obj.connection_id || ''});
    Object.defineProperty(obj, 'isConnection', {get: () => true});
    this.res.body.connections = this.connections.filter(c => c.id != obj.id).concat(obj);
    if (params.calculate !== false) this._calculateConnectionsWithChannels();
  }

  ensureDialog(obj, params = {}) {
    Object.defineProperty(obj, 'id', {get: () => obj.dialog_id || ''});
    Object.defineProperty(obj, 'isDialog', {get: () => true});
    obj.messages = this._messages(obj);
    obj.path = encodeURIComponent(obj.id);
    this.res.body.dialogs = this.dialogs.filter(d => d.id != obj.id).concat(obj);
    if (params.calculate !== false) this._calculateConnectionsWithChannels();
  }

  parse(res, body = res.body) {
    Operation.prototype.parse.call(this, res, body);
    if (body.connections) body.connections.forEach(c => this.ensureConnection(c, {calculate: false}));
    if (body.dialogs) body.dialogs.forEach(d => this.ensureDialog(d, {calculate: false}));
    if (this.is('success')) this._calculateConnectionsWithChannels();
    return this;
  }

  async send(msg) {
    const ws = await this._ws();
    if (!msg.id) msg.id = (++this.msgId);
    ws.send(JSON.stringify(msg));
  }

  _calculateConnectionsWithChannels() {
    const map = {};

    this.connections.forEach(conn => {
      map[conn.id] = conn;
    });

    this.dialogs.forEach(dialog => {
      map[dialog.connection_id][dialog.is_private ? 'private' : 'channels'].push(dialog);
    });

    this.connectionsWithChannels.set(Object.keys(map).sort().map(id => {
      map[id].channels.sort(byName);
      map[id].private.sort(byName);
      return map[id];
    }));

    return this._notifySubscribers();
  }

  _messages(params) {
    return new Messages({...params, api: this.api});
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
        this.connections.forEach(conn => { conn.status = 'Unreachable' });
        this.dialogs.forEach(dialog => { dialog.frozen = 'No internet connection?' });
        if (![handled, (handled = true)][0]) reject(e);
      };

      ws.onerror = ws.onclose;

      ws.onmessage = (e) => {
        var data = JSON.parse(e.data);

        if (data.connection_id && data.event) {
          console.log('TODO', data);
        }
        else if (data.email) {
          this.parse({body: data});
        }
      };
    });
  }
}
