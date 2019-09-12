import Connection from './Connection';
import Dialog from './Dialog';
import Events from '../js/Events';
import Operation from './Operation';
import {sortByName} from '../js/util';

export default class User extends Operation {
  constructor(params) {
    super({
      api: params.api,
      defaultParams: {connections: true, dialogs: true, notifications: true},
      id: 'getUser',
    });

    this._readOnlyAttr('email', () => this.res.body.email || '');
    this._readOnlyAttr('notifications', new Dialog({api: this.api, name: 'Notifications'}));
    this._readOnlyAttr('events', this._createEvents());

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
    conn.on('message', params => this.send(params));
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

  send(msg, cb) {
    return this.events.send(msg, cb);
  }

  wsEventMe(params) {
    this.ensureDialog({connection_id: params.connection_id}).update(params);
  }

  wsEventPong(params) {
    this.wsPongTimestamp = params.ts;
  }

  _createEvents() {
    const events = new Events();

    events.on('message', params => {
      const conn = this.findDialog({connection_id: params.connection_id});
      if (conn && conn[params.dispatchTo]) conn[params.dispatchTo](params);
      if (this[params.dispatchTo]) this[params.dispatchTo](params);
    });

    events.on('update', events => {
      if (events.state == 'closed') this.connections.forEach(conn => conn.update({frozen: 'Unreachable.'}));
    });

    return events;
  }
}
