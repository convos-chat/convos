import Connection from './Connection';
import Events from '../js/Events';
import Notifications from './Notifications';
import Reactive from '../js/Reactive';
import {sortByName} from '../js/util';

export default class User extends Reactive {
  constructor(params) {
    super();

    const api = params.api;
    this._readOnlyAttr('api', () => api);
    this._readOnlyAttr('email', () => this.getUserOp.res.body.email || '');
    this._readOnlyAttr('events', this._createEvents());

    this._updateableAttr('connections', []);
    this._updateableAttr('expandUrlToMedia', true);
    this._updateableAttr('icon', 'user-circle');

    this._readOnlyAttr('getUserOp', api.operation('getUser', {connections: true, dialogs: true, notifications: true}));
    this._readOnlyAttr('notifications', new Notifications({api, events: this.events, messagesOp: this.getUserOp}));
  }

  ensureDialog(params) {
    // Ensure channel or private dialog
    if (params.dialog_id) {
      return this.ensureDialog({connection_id: params.connection_id}).ensureDialog(params);
    }

    // Find connection
    let conn = this.findDialog(params);
    if (conn) return conn.update(params);

    // Create connection
    conn = new Connection({...params, api: this.api, events: this.events});

    // TODO: Figure out how to update Chat.svelte, without updating the user object
    conn.on('update', () => this.update({}));

    this.connections.push(conn);
    this.connections.sort(sortByName);
    this.update({});
    return conn;
  }

  findDialog(params) {
    if (!params.dialog_id) return this.connections.find(conn => conn.connection_id == params.connection_id);
    const conn = this.findDialog({connection_id: params.connection_id});
    return conn && conn.findDialog(params);
  }

  is(status) {
    return this.getUserOp.is(status);
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

  removeDialog(params) {
    if (params.dialog_id) {
      const conn = this.findDialog({connection_id: params.connection_id});
      if (conn) conn.removeDialog(params);
    }
    else {
      this.update({connections: this.connections.filter(c => c.connection_id != params.connection_id)});
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
      this._dispatchMessageToDialog(params);
      if (this[params.dispatchTo]) this[params.dispatchTo](params);
    });

    events.on('update', events => {
      if (events.ready) return;
      this.getUserOp.update({status: 'pending'});
      this.connections.forEach(c => c.update({frozen: 'Unreachable.'}));
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
    this.update({connections: []});
    this.notifications.addMessages('set', body.notifications || []);
    this.notifications.update({unread: body.unread || 0});
    (body.connections || []).forEach(c => this.ensureDialog(c));
    (body.dialogs || []).forEach(d => this.ensureDialog(d));
  }
}
