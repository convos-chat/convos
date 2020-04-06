import Connection from './Connection';
import Dialog from './Dialog';
import EmbedMaker from '../js/EmbedMaker';
import Notifications from './Notifications';
import Reactive from '../js/Reactive';
import Search from './Search';
import SortedMap from '../js/SortedMap';
import {extractErrorMessage} from '../js/util';
import {omnibus} from '../store/Omnibus';
import {route} from './Route';

export default class User extends Reactive {
  constructor(params) {
    super();

    const api = params.api;
    this.prop('ro', 'api', () => api);
    this.prop('ro', 'connections', new SortedMap());
    this.prop('ro', 'email', () => this.getUserOp.res.body.email || '');
    this.prop('ro', 'embedMaker', new EmbedMaker({api}));
    this.prop('ro', 'isFirst', params.isFirst || false);
    this.prop('ro', 'getUserOp', api.operation('getUser', {connections: true, dialogs: true}));
    this.prop('ro', 'notifications', new Notifications({api}));
    this.prop('ro', 'omnibus', params.omnibus || omnibus);
    this.prop('ro', 'search', new Search({api}));
    this.prop('ro', 'roles', new Set());
    this.prop('ro', 'themes', params.themes || {});
    this.prop('ro', 'unread', () => this._calculateUnread());

    this.prop('rw', 'activeDialog', this.notifications);
    this.prop('rw', 'highlight_keywords', []);
    this.prop('rw', 'status', 'pending');

    this.prop('persist', 'assetVersion', 0);
    this.prop('persist', 'colorScheme', 'auto');
    this.prop('persist', 'experimentalLoad', false);
    this.prop('persist', 'showGrid', false);
    this.prop('persist', 'theme', 'convos');

    const matchMedia = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : {addListener: function() {}};
    if (matchMedia.matches) this._osColorScheme = 'dark';
    matchMedia.addListener(e => { this._osColorScheme = e.matches ? 'dark' : 'light' });

    this._listenToOmnibus();

    // Used to test WebSocket reconnect logic
    // setInterval(() => (this.omnibus.ws && this.omnibus.ws.close()), 3000);
  }

  activateTheme() {
    const colorScheme = this.colorScheme == 'auto' ? this._osColorScheme : this.colorScheme;
    const theme = this.themes[this.theme];
    if (!theme) return console.error('[Convos] Invalid theme: ' + this.theme);

    const file = theme.color_schemes[colorScheme] || theme.color_schemes.default;
    document.getElementById('link_selected_theme').setAttribute('href', route.urlFor('/themes/' + file));

    const htmlEl = document.documentElement;
    htmlEl.className = htmlEl.className.replace(/theme-\S+/, () => 'theme-' + theme.id);
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

  ensureDialog(params, _lock) {
    // Ensure channel or private dialog
    if (params.dialog_id) {
      const conn = this.ensureDialog({connection_id: params.connection_id}, true);
      return this._maybeUpgradeActiveDialog(conn.ensureDialog(params));
    }

    // Find connection
    let conn = this.findDialog(params);
    if (conn) return conn.update(params);

    // Create connection
    conn = new Connection({...params, api: this.api});

    // TODO: Figure out how to update Chat.svelte, without updating the user object
    conn.on('dialogadd', (dialog) => this._maybeUpgradeActiveDialog(dialog));
    conn.on('dialogremove', (dialog) => (dialog == this.activeDialog && this.setActiveDialog(dialog)));
    conn.on('update', (conn) => this.update({connections: true}));
    this.connections.set(conn.connection_id, conn);
    this.update({connections: true});
    return _lock ? conn : this._maybeUpgradeActiveDialog(conn);
  }

  findDialog(params) {
    const conn = this.connections.get(params.connection_id);
    return !params.dialog_id ? conn : conn && conn.findDialog(params) || null;
  }

  is(statusOrRole) {
    if (Array.isArray(statusOrRole)) return !!statusOrRole.filter(sr => this.is(sr)).length;
    if (this.roles.has(statusOrRole)) return true;
    if (statusOrRole == 'offline') return extractErrorMessage(this.getUserOp.err || [], 'source') == 'fetch';
    return this.status == statusOrRole;
  }

  async load(load) {
    if (load === false) {
      this.roles.add('anonymous');
      this.update({roles: true});
      return this;
    }

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
    this.roles.add(body.email ? 'authenticated' : 'anonymous');
    (body.roles || []).forEach(role => this.roles.add(role));
    if (this.email) this.omnibus.send('ping');

    this.update({
      highlight_keywords: body.highlight_keywords || [],
      roles: true,
      status: this.getUserOp.status,
    });

    return this;
  }

  removeDialog(params) {
    const conn = this.findDialog({connection_id: params.connection_id});
    if (params.dialog_id) return conn && conn.removeDialog(params);
    this.connections.delete(params.connection_id);
    if (conn == this.activeDialog) this.setActiveDialog(conn);
    this.update({connections: true});
  }

  setActiveDialog(params) {
    let activeDialog = !params.connection_id && !params.dialog_id && this.notifications;
    if (activeDialog) return this.update({activeDialog});

    activeDialog = this.findDialog(params);
    if (activeDialog) return this.update({activeDialog});

    // Need to expand params manually, in case we are passing in a reactive object
    const props = {...params, connection_id: params.connection_id || '', api: this.api, frozen: 'Not found.'};
    ['dialog_id', 'name'] .forEach(k => params.hasOwnProperty(k) && (props[k] = params[k]));
    return this.update({activeDialog: props.dialog_id ? new Dialog(props) : new Connection(props)});
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

  _dispatchMessageToDialog(params) {
    const conn = this.findDialog({connection_id: params.connection_id});
    if (!conn) return;
    if (conn[params.dispatchTo]) conn[params.dispatchTo](params);
    if (!params.bubbles) return;

    const dialog = conn.findDialog(params);
    if (dialog && dialog[params.dispatchTo]) dialog[params.dispatchTo](params);
  }

  _listenToOmnibus() {
    this.omnibus.on('close', () => {
      this.update({status: 'pending'});
      this.connections.forEach(conn => conn.update({state: 'unreachable'}));
    });

    this.omnibus.on('open', () => {
      if (this.is('pending') && this.email) return this.load();
    });

    this.omnibus.on('message', params => {
      this._dispatchMessageToDialog(params);
      this.emit(params.dispatchTo, params);
      if (this[params.dispatchTo]) this[params.dispatchTo](params);
    });

    this.omnibus.on('serviceWorker', (reg) => {
      const assetVersion = process.env.asset_version;
      if (this.omnibus.debug) console.log('[serviceWorker]', [this.assetVersion, assetVersion].join(' == '));
      if (this.assetVersion == assetVersion) return;
      reg.update();
      this.update({assetVersion});
    });
  }

  _maybeUpgradeActiveDialog(dialog) {
    const active = this.activeDialog;
    if (dialog.connection_id && dialog.connection_id != active.connection_id) return dialog;
    if (dialog.dialog_id && dialog.dialog_id != active.dialog_id) return dialog;
    this.update({activeDialog: dialog});
    return dialog;
  }
}
