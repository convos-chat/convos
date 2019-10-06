import Connection from './Connection';
import Dialog from './Dialog';
import Events from '../js/Events';
import Reactive from '../js/Reactive';
import ReactiveList from '../store/ReactiveList';

export default class User extends Reactive {
  constructor(params) {
    super();

    const api = params.api;
    this._readOnlyAttr('api', () => api);
    this._readOnlyAttr('connections', new ReactiveList());
    this._readOnlyAttr('email', () => this.getUserOp.res.body.email || '');
    this._readOnlyAttr('events', this._createEvents());

    // Need to come after "api" and "events"
    this._readOnlyAttr('notifications', new Dialog({api, events: this.events, name: 'Notifications'}));

    this._updateableAttr('expandUrlToMedia', true);
    this._updateableAttr('icon', 'user-circle');

    // Add operations that will affect the "User" object
    // TODO: Make operations bubble into the User object. Require changes in App.svelte
    this._readOnlyAttr('getUserOp', api.operation('getUser', {connections: true, dialogs: true, notifications: true}));
    this._readOnlyAttr('loginOp', api.operation('loginUser'));
    this._readOnlyAttr('logoutOp', api.operation('logoutUser'));
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

    // TODO: Figure out how to update Chat.svelte, without updating the user object
    conn.on('update', () => this.update({}));

    this.connections.add(conn).sort();
    return conn;
  }

  findDialog(params) {
    if (!params.dialog_id) return this.connections.find(conn => conn.connection_id == params.connection_id);
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

  removeDialog(params) {
    if (params.dialog_id) {
      const conn = this.findDialog({connection_id: params.connection_id});
      if (conn) conn.removeDialog(params);
      this.update({});
    }
    else {
      this.connections.remove(conn => conn.connection_id != params.connection_id);
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
      this.connections.map(conn => conn.update({frozen: 'Unreachable.'}));
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
    this.connections.clear();
    if (body.notifications) this.notifications.update({messages: body.notifications, unread: body.unread}); // Need to be done before this.update()
    if (body.connections) body.connections.forEach(c => this.ensureDialog(c));
    if (body.dialogs) body.dialogs.forEach(d => this.ensureDialog(d));
    return this;
  }
}
