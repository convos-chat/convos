import Connection from './Connection';
import Dialog from './Dialog';
import EmbedMaker from '../js/EmbedMaker';
import Notifications from './Notifications';
import Reactive from '../js/Reactive';
import Search from './Search';
import SortedMap from '../js/SortedMap';
import {camelize, extractErrorMessage} from '../js/util';
import {route} from './Route';
import {socket} from './../js/Socket';

export default class User extends Reactive {
  constructor(params) {
    super();

    const api = params.api;
    this.prop('ro', 'api', () => api);
    this.prop('ro', 'connections', new SortedMap());
    this.prop('ro', 'email', () => this.getUserOp.res.body.email || '');
    this.prop('ro', 'embedMaker', new EmbedMaker());
    this.prop('ro', 'isFirst', params.isFirst || false);
    this.prop('ro', 'getUserOp', api.operation('getUser', {connections: true, dialogs: true}));
    this.prop('ro', 'notifications', new Notifications({api}));
    this.prop('ro', 'search', new Search({api}));
    this.prop('ro', 'roles', new Set());
    this.prop('ro', 'themes', params.themes || {});
    this.prop('ro', 'unread', () => this._calculateUnread());

    this.prop('rw', 'activeDialog', this.notifications);
    this.prop('rw', 'highlight_keywords', []);
    this.prop('rw', 'rtc', {});
    this.prop('rw', 'status', 'pending');

    this.prop('persist', 'assetVersion', 0);
    this.prop('persist', 'experimentalLoad', false);
    this.prop('persist', 'showGrid', false);

    this.prop('cookie', 'colorScheme', 'auto');
    this.prop('cookie', 'theme', 'convos');

    socket('/events').on('message', (msg) => this._dispatchMessage(msg));
    socket('/events').on('update', (socket) => this._onConnectionChange(socket));

    const matchMedia = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : {addListener: function() {}};
    if (matchMedia.matches) this._osColorScheme = 'dark';
    matchMedia.addListener(e => { this._osColorScheme = e.matches ? 'dark' : 'light' });
  }

  activateTheme() {
    const colorScheme = this.colorScheme == 'auto' ? this._osColorScheme : this.colorScheme;
    const theme = this.themes[this.theme];
    if (!theme) return console.error('[Convos] Invalid theme: ' + this.theme);

    const path = theme.variants[colorScheme] || theme.variants.default;
    document.getElementById('link_selected_theme').setAttribute('href', route.urlFor(path));

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
    if (this.email) socket('/events', {});

    this.update({
      highlight_keywords: body.highlight_keywords || [],
      roles: true,
      rtc: body.rtc || {},
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

  _calculateUnread() {
    const activeDialog = this.activeDialog;
    return this.notifications.unread
      + this.dialogs(dialog => dialog.is_private)
          .reduce((t, d) => { return t + (d == activeDialog ? 0 : d.unread) }, 0);
  }

  _dispatchMessage(msg) {
    msg.dispatchTo = camelize('wsEvent_' + this._getEventNameFromMessage(msg));
    msg.bubbles = true;
    msg.stopPropagation = () => { msg.bubbles = false };
    this.emit(msg.dispatchTo, msg);

    const conn = this.findDialog({connection_id: msg.connection_id});
    if (!conn) return;
    if (conn[msg.dispatchTo]) conn[msg.dispatchTo](msg);
    if (!msg.bubbles) return;

    const dialog = conn.findDialog(msg);
    if (dialog && dialog[msg.dispatchTo]) dialog[msg.dispatchTo](msg);
  }

  _getEventNameFromMessage(msg) {
    if (msg.errors) return 'error';
    if (msg.event == 'state') return msg.type;

    if (msg.event == 'sent' && msg.message.match(/\/\S+/)) {
      msg.command = msg.message.split(/\s+/).filter(s => s.length);
      msg.command[0] = msg.command[0].substring(1);
      return 'sent_' + msg.command[0];
    }

    return msg.event;
  }

  _maybeUpgradeActiveDialog(dialog) {
    const active = this.activeDialog;
    if (dialog.connection_id && dialog.connection_id != active.connection_id) return dialog;
    if (dialog.dialog_id && dialog.dialog_id != active.dialog_id) return dialog;
    this.update({activeDialog: dialog});
    return dialog;
  }

  _onConnectionChange(socket) {
    if (socket.is('close')) {
      this.connections.forEach(conn => conn.update({state: 'unreachable'}));
      this.update({status: 'pending'});
    }
    else if (socket.is('open')) {
      this.load();
    }
  }
}
