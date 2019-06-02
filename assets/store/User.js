import ConnURL from '../js/ConnURL';
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
    ['connections', 'dialogs', 'notifications'].forEach(name => {
      Object.defineProperty(this, name, {get: () => { return this.res.body[name] || [] }});
    });

    Object.defineProperty(this, 'email', {get: () => this.res.body.email || ''});

    // Add operations that will affect the "User" object
    // TODO: Make operations bubble into the User object. Require changes in App.svelte
    this.login = this.api.operation('loginUser');
    this.logout = this.api.operation('logoutUser');
    this.register = this.api.operation('registerUser');
    this.readNotifications = this.api.operation('readNotifications');

    // "User" is a store, but it has sub svelte stores that can be watched
    this.connectionsWithChannels = writable([]);
    this.enableNotifications = writable(Notification.permission);
    this.expandUrlToMedia = writable(false);
  }

  ensureConnection(obj, params = {}) {
    obj.url = typeof obj.url == 'string' ? new ConnURL(obj.url) : obj.url;
    Object.defineProperty(obj, 'id', {get: () => obj.connection_id || ''});
    Object.defineProperty(obj, 'isConnection', {get: () => true});
    this.res.body.connections = this.connections.filter(c => c.id != obj.id).concat(obj);
    if (params.calculate !== false) this._calculateConnectionsWithChannels();
  }

  ensureDialog(obj, params = {}) {
    Object.defineProperty(obj, 'id', {get: () => obj.dialog_id || ''});
    Object.defineProperty(obj, 'isDialog', {get: () => true});
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

  _calculateConnectionsWithChannels() {
    const map = {};
    this.connections.forEach(conn => {
      conn.channels = [];
      conn.private = [];
      map[conn.id] = conn;
    });

    this.dialogs.forEach(dialog => {
      const conn = map[dialog.connection_id];
      dialog.path = encodeURIComponent(dialog.id);
      conn[dialog.is_private ? 'private' : 'channels'].push(dialog);
    });

    this.connectionsWithChannels.set(Object.keys(map).sort().map(id => {
      map[id].channels.sort(byName);
      map[id].private.sort(byName);
      return map[id];
    }));

    return this._notifySubscribers();
  }
}
