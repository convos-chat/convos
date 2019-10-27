import Connection from './Connection';
import EmbedMaker from '../js/EmbedMaker';
import Events from '../js/Events';
import Notifications from './Notifications';
import Reactive from '../js/Reactive';
import SortedMap from '../js/SortedMap';

export default class User extends Reactive {
  constructor(params) {
    super();

    const api = params.api;
    this._readOnlyAttr('api', () => api);
    this._readOnlyAttr('connections', new SortedMap());
    this._readOnlyAttr('email', () => this.getUserOp.res.body.email || '');
    this._readOnlyAttr('embedMaker', new EmbedMaker({api}));
    this._readOnlyAttr('events', this._createEvents(params));
    this._readOnlyAttr('getUserOp', api.operation('getUser', {connections: true, dialogs: true, notifications: true}));
    this._readOnlyAttr('notifications', new Notifications({api, events: this.events, messagesOp: this.getUserOp}));

    this._localStorageAttr('lastUrl', '');
    this._localStorageAttr('showGrid', false);
    this._localStorageAttr('theme', 'auto');

    this._proxyAttr('expandUrlToMedia', 'embedMaker');
    this._proxyAttr('wantNotifications', 'events');
    this._proxyAttr('status', 'getUserOp');
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

    this.connections.set(conn.connection_id, conn);
    this.update({});
    return conn;
  }

  findDialog(params) {
    const conn = this.connections.get(params.connection_id);
    return !params.dialog_id ? conn : conn && conn.findDialog(params);
  }

  is(status) {
    return this.getUserOp.is(status);
  }

  async load() {
    if (this.getUserOp.is('success')) return this;
    await this.getUserOp.perform();
    this._parseGetUser(this.getUserOp.res.body);
    if (this.email) this.send({method: 'ping'});
    return this;
  }

  removeDialog(params) {
    if (params.dialog_id) {
      const conn = this.findDialog({connection_id: params.connection_id});
      if (conn) conn.removeDialog(params);
    }
    else {
      this.connections.delete(params.connection_id);
      this.update({});
    }
  }

  send(msg, cb) {
    return this.events.send(msg, cb);
  }

  wsEventMe(params) {
    const conn = this.ensureDialog({connection_id: params.connection_id});
    conn.wsEventNickChange(params);
    conn.update(params);
  }

  wsEventPart(params) {
    this.emit('dialogEvent', params);
  }

  wsEventPong(params) {
    this.wsPongTimestamp = params.ts;
  }

  wsEventSentJoin(params) {
    this.emit('dialogEvent', params);
  }

  _createEvents(params) {
    const events = new Events(params);

    events.on('message', params => {
      this._dispatchMessageToDialog(params);
      if (this[params.dispatchTo]) this[params.dispatchTo](params);
    });

    events.on('update', events => {
      if (events.ready) {
        return this.getUserOp.is('pending') ? this.load() : false;
      }
      else {
        this.getUserOp.update({status: 'pending'});
        this.connections.forEach(conn => conn.update({state: 'unreachable'}));
      }
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
    this.notifications.addMessages('set', body.notifications || []);
    this.notifications.update({unread: body.unread || 0});
    (body.connections || []).forEach(conn => this.ensureDialog(conn));
    (body.dialogs || []).forEach(dialog => this.ensureDialog(dialog));
    this.update({}); // Force update on error
  }
}
