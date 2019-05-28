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
      Object.defineProperty(this, name, {
        get: () => { return this.res.body[name] || [] },
        set: (val) => { this.res.body[name] = val },
      });
    });

    Object.defineProperty(this, 'email', {get: () => this.res.body.email || ''});

    // Add operations that will affect the "User" object
    // TODO: Make operations bubble into the User object. Require changes in App.svelte
    this.login = this.api.operation('loginUser');
    this.logout = this.api.operation('logoutUser');
    this.register = this.api.operation('registerUser');

    // "User" is a store, but it has sub svelte stores that can be watched
    this.connectionsWithChannels = writable([]);
    this.enableNotifications = writable(Notification.permission);
    this.expandUrlToMedia = writable(false);
  }

  ensureConnection(conn) {
    conn.url = typeof conn.url == 'string' ? new ConnURL(conn.url) : conn.url;
    this.connections = this.connections.filter(c => c.connection_id != conn.connection_id).concat(conn);
    this._calculateConnectionsWithChannels();
  }

  ensureDialog(dialog) {
    this.dialogs = this.dialogs.filter(d => d.dialog_id != dialog.dialog_id).concat(dialog);
    this._calculateConnectionsWithChannels();
  }

  parse(res, body = res.body) {
    Operation.prototype.parse.call(this, res, body);
    if (body.connections) body.connections.forEach(c => this.ensureConnection(c));
    if (body.dialogs) body.dialogs.forEach(d => this.ensureDialog(d));
    if (this.is('success')) this._calculateConnectionsWithChannels();
    return this;
  }

  _calculateConnectionsWithChannels() {
    const map = {};
    (this.res.body.connections || []).forEach(conn => {
      conn.channels = [];
      conn.private = [];
      map[conn.connection_id] = conn;
    });

    (this.res.body.dialogs || []).forEach(dialog => {
      const conn = map[dialog.connection_id];
      dialog.path = encodeURIComponent(dialog.dialog_id);
      conn[dialog.is_private ? 'private' : 'channels'].push(dialog);
    });

    this.connectionsWithChannels.set(Object.keys(map).sort().map(id => {
      map[id].channels.sort(byName);
      map[id].private.sort(byName);
      return map[id];
    }));
  }
}