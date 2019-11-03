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
    this.prop('ro', 'api', () => api);
    this.prop('ro', 'connections', new SortedMap());
    this.prop('ro', 'email', () => this.getUserOp.res.body.email || '');
    this.prop('ro', 'embedMaker', new EmbedMaker({api}));
    this.prop('ro', 'events', this._createEvents(params));
    this.prop('ro', 'getUserOp', api.operation('getUser', {connections: true, dialogs: true, notifications: true}));
    this.prop('ro', 'notifications', new Notifications({api, events: this.events, messagesOp: this.getUserOp}));
    this.prop('ro', 'unread', () => this._calculateUnread());

    this.prop('rw', 'highlight_keywords', []);

    this.prop('persist', 'lastUrl', '');
    this.prop('persist', 'showGrid', false);
    this.prop('persist', 'theme', 'auto');
    this.prop('persist', 'version', 0);

    this.prop('proxy', 'expandUrlToMedia', 'embedMaker');
    this.prop('proxy', 'wantNotifications', 'events');
    this.prop('proxy', 'status', 'getUserOp');
  }

  dialogs(cb) {
    const dialogs = [];

    this.connections.toArray().forEach(conn => {
      conn.dialogs.toArray().forEach(dialog => {
        if (!cb || cb(dialog)) dialogs.push(dialog);
      });
    });

    return dialogs;
  }

  ensureConnected() {
    this.events.ensureConnected();
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
    conn.on('update', () => this.update({connections: this.connections.size}));

    this.connections.set(conn.connection_id, conn);
    this.update({connections: this.connections.size});
    return conn;
  }

  findDialog(params) {
    const conn = this.connections.get(params.connection_id);
    return !params.dialog_id ? conn : conn && conn.findDialog(params);
  }

  is(status) {
    return this.getUserOp.is(status);
  }

  async load(user) {
    if (user) {
      this.getUserOp.parse({status: 200}, user);
    }
    else if (this.getUserOp.is('success')) {
      return this;
    }
    else {
      await this.getUserOp.perform();
    }

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
      this.update({connections: this.connections.size});
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

  wsEventPong(params) {
    this.wsPongTimestamp = params.ts;
  }

  _calculateUnread() {
    return this.notifications.unread
      + this.dialogs(dialog => dialog.is_private).reduce((t, d) => { return t + d.unread }, 0);
  }

  _createEvents(params) {
    const events = new Events(params);

    events.on('message', params => {
      this._dispatchMessageToDialog(params);
      this.emit(params.dispatchTo, params);
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
    this.update({highlight_keywords: body.highlight_keywords}); // Force update on error
  }
}
