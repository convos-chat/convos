import Connection from './Connection';
import Dialog from './Dialog';
import Events from '../js/Events';
import Reactive from '../js/Reactive';
import {get, writable} from 'svelte/store';
import {sortByName} from '../js/util';

const providers = {
  instagram: {
    isLoaded() { return window.instgrm },
    reload() { window.instgrm.Embeds.process() },
    url: '//platform.instagram.com/en_US/embeds.js',
  },
  twitter: {
    isLoaded() { return window.twttr },
    reload() { window.twttr.widgets.load() },
    url: '//platform.twitter.com/widgets.js',
  },
};

export default class User extends Reactive {
  constructor(params) {
    super();

    const api = params.api;
    this._readOnlyAttr('api', () => api);
    this._readOnlyAttr('email', () => this.getUserOp.res.body.email || '');
    this._readOnlyAttr('events', this._createEvents());

    // Need to come after "api" and "events"
    this._readOnlyAttr('notifications', new Dialog({api, events: this.events, name: 'Notifications'}));

    this._updateableAttr('connections', writable([]));
    this._updateableAttr('enableNotifications', Notification.permission);
    this._updateableAttr('expandUrlToMedia', true);
    this._updateableAttr('icon', 'user-circle');

    // Add operations that will affect the "User" object
    // TODO: Make operations bubble into the User object. Require changes in App.svelte
    this._readOnlyAttr('getUserOp', api.operation('getUser', {connections: true, dialogs: true, notifications: true}));
    this._readOnlyAttr('loginOp', api.operation('loginUser'));
    this._readOnlyAttr('logoutOp', api.operation('logoutUser'));
    this._readOnlyAttr('readNotificationsOp', api.operation('readNotifications'));
    this._readOnlyAttr('registerOp', api.operation('registerUser'));
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
    conn = new Connection({...params, api: this.api, events: this.events});
    conn.on('update', () => {
      this.connections.set(this._connections().sort(sortByName));
      this.update({}); // TODO: Figure out how to update Chat.svelte, without updating the user object
    });

    this.connections.set(this._connections().concat(conn).sort(sortByName));
    return conn;
  }

  findDialog(params) {
    if (!params.dialog_id) return this._connections().filter(conn => conn.connection_id == params.connection_id)[0];
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
    if (this.getUserOp.is('success')) return this;
    await this.getUserOp.perform();
    this._parseGetUser(this.getUserOp.res.body);
    if (this.email) await this.send({method: 'ping'});
    return this;
  }

  loadProvider(name) {
    // TODO: Allow providers to be disabled
    const provider = providers[name];
    if (!provider) return;
    if (provider.isLoaded()) return provider.reload();
    const el = document.createElement('script');
    el.id = provider.url.replace(/\W/g, '_');
    el.src = provider.url;
    document.getElementsByTagName('head')[0].appendChild(el);
  }

  removeDialog(params) {
    if (params.dialog_id) {
      const conn = this.findDialog({connection_id: params.connection_id});
      if (conn) conn.removeDialog(params);
      this.update({});
    }
    else {
      this.connections.set(this._connections().filter(conn => conn.connection_id != params.connection_id));
    }
  }

  send(msg, cb) {
    return this.events.send(msg, cb);
  }

  wsEventMe(params) {
    this.ensureDialog({connection_id: params.connection_id}).update(params);
  }

  wsEventPong(params) {
    this.wsPongTimestamp = params.ts;
  }

  _connections() {
    return get(this.connections);
  }

  _createEvents() {
    const events = new Events();

    events.on('message', params => {
      this._dispatchMessageToDialog(params);
      if (this[params.dispatchTo]) this[params.dispatchTo](params);
    });

    events.on('update', events => {
      if (events.ready) return;
      this.getUserOp.update({status: 'pending'});
      this._connections().forEach(conn => conn.update({frozen: 'Unreachable.'}));
    });

    return events;
  }

  _dispatchMessageToDialog(params) {
    const conn = this.findDialog({connection_id: params.connection_id});
    if (!conn) return;
    if (conn[params.dispatchTo]) conn[params.dispatchTo](params);
    if (!params.bubbles) return;

    const dialog = conn.findDialog(params);
    if (!dialog) return;
    if (dialog[params.dispatchTo]) dialog[params.dispatchTo](params);
  }

  _parseGetUser(body) {
    this.connections.set([]);
    if (body.notifications) this.notifications.update({messages: body.notifications}); // Need to be done before this.update()
    if (body.connections) body.connections.forEach(c => this.ensureDialog(c));
    if (body.dialogs) body.dialogs.forEach(d => this.ensureDialog(d));
    return this;
  }
}
