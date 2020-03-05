import Connection from './Connection';
import EmbedMaker from '../js/EmbedMaker';
import Events from '../js/Events';
import Notifications from './Notifications';
import Reactive from '../js/Reactive';
import Search from './Search';
import SortedMap from '../js/SortedMap';
import {extractErrorMessage} from '../js/util';
import {urlFor} from './router';

export default class User extends Reactive {
  constructor(params) {
    super();

    const api = params.api;
    this.prop('ro', 'api', () => api);
    this.prop('ro', 'connections', new SortedMap());
    this.prop('ro', 'email', () => this.getUserOp.res.body.email || '');
    this.prop('ro', 'embedMaker', new EmbedMaker({api}));
    this.prop('ro', 'events', this._createEvents(params));
    this.prop('ro', 'getUserOp', api.operation('getUser', {connections: true, dialogs: true}));
    this.prop('ro', 'notifications', new Notifications({api, events: this.events}));
    this.prop('ro', 'search', new Search({api, events: this.events}));
    this.prop('ro', 'roles', new Set());
    this.prop('ro', 'themes', params.themes || {});
    this.prop('ro', 'unread', () => this._calculateUnread());

    this.prop('rw', 'highlight_keywords', []);
    this.prop('rw', 'status', 'pending');

    this.prop('persist', 'colorScheme', 'auto');
    this.prop('persist', 'experimentalLoad', false);
    this.prop('persist', 'lastUrl', '');
    this.prop('persist', 'showGrid', false);
    this.prop('persist', 'theme', 'convos');
    this.prop('persist', 'version', '0');

    const matchMedia = window.matchMedia('(prefers-color-scheme: dark)');
    if (matchMedia.matches) this._osColorScheme = 'dark';
    matchMedia.addListener(e => { this._osColorScheme = e.matches ? 'dark' : 'light' });

    // Used to test WebSocket reconnect logic
    // setInterval(() => (this.events.ws && this.events.ws.close()), 3000);
  }

  activateTheme() {
    const colorScheme = this.colorScheme == 'auto' ? this._osColorScheme : this.colorScheme;
    const theme = this.themes[this.theme];
    if (!theme) return console.error('[Convos] Invalid theme: ' + this.theme);

    const file = theme.color_schemes[colorScheme] || theme.color_schemes.default;
    document.getElementById('link_selected_theme').setAttribute('href', urlFor('/themes/' + file));

    const htmlEl = document.documentElement;
    htmlEl.className = htmlEl.className.replace(/theme-\S+/, () => 'theme-' + theme.id);
  }

  calculateLastUrl() {
    if (this.is('error')) return urlFor('/login');
    if (!this.is('success')) return null;
    if (this.lastUrl) return this.lastUrl;

    const conn = this.connections.toArray()[0];
    if (!conn) return urlFor('/settings/connection');

    const dialog = conn.dialogs.toArray()[0];
    return urlFor(dialog ? dialog.path : conn.path);
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
    if (this.email) this.send({method: 'ping'});
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
    conn.on('update', () => this.update({force: true}));
    conn.on('channelListChange', (dialog) => this.emit('channelListChange', dialog));
    this.connections.set(conn.connection_id, conn);
    this.update({force: true});
    return conn;
  }

  findDialog(params) {
    const conn = this.connections.get(params.connection_id);
    return !params.dialog_id ? conn : conn && conn.findDialog(params);
  }

  is(status) {
    if (Array.isArray(status)) return !!status.filter(s => this.is(s)).length;
    if (status == 'loggedIn') return this.email && true;
    if (status == 'offline') return extractErrorMessage(this.getUserOp.err || [], 'source') == 'fetch';
    return this.status == status;
  }

  async load() {
    if (this.is('loading')) return this;

    this.update({status: 'loading'});
    await this.getUserOp.perform();

    const body = this.getUserOp.res.body;
    const keep = {};
    if (!this.experimentalLoad) this.connections.clear();
    (body.connections || []).forEach(conn => (keep[this.ensureDialog({...conn, status: 'pending'}).path] = true));
    (body.dialogs || []).forEach(dialog => (keep[this.ensureDialog({...dialog, status: 'pending'}).path] = true));

    // Remove connections and dialogs that is not part of the new response
    this.connections.forEach(conn => {
      if (!keep[conn.path]) return this.connections.delete(conn.connection_id);
      conn.dialogs.forEach(dialog => {
        if (!keep[dialog.path]) conn.dialogs.delete(dialog.dialog_id);
      });
    });

    this.notifications.update({unread: body.unread || 0});
    this.roles.clear();
    (body.roles || []).forEach(role => this.roles.add(role));
    this.update({highlight_keywords: body.highlight_keywords || [], status: this.getUserOp.status});
    this.ensureConnected();

    return this;
  }

  removeDialog(params) {
    if (params.dialog_id) {
      const conn = this.findDialog({connection_id: params.connection_id});
      if (conn) conn.removeDialog(params);
    }
    else {
      this.connections.delete(params.connection_id);
      this.update({force: true});
    }
  }

  send(msg, cb) {
    return this.events.send(msg, cb);
  }

  update(params) {
    super.update(params);
    if (params.colorScheme || params.theme) this.activateTheme();
    return this;
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
      if (events.ready) return this.is('pending') && this.load();
      this.update({status: 'pending'});
      this.connections.forEach(conn => conn.update({state: 'unreachable'}));
    });

    return events;
  }

  _dispatchMessageToDialog(params) {
    const conn = this.findDialog({connection_id: params.connection_id});
    if (!conn) return;
    if (conn[params.dispatchTo]) conn[params.dispatchTo](params);
    if (!params.bubbles) return;

    const dialog = conn.findDialog(params);
    if (dialog && dialog[params.dispatchTo]) dialog[params.dispatchTo](params);
  }
}
