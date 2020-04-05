import Reactive from '../js/Reactive';
import {camelize, clone} from '../js/util';
import {l} from '../js/i18n';
import {route} from '../store/Route';

export default class Omnibus extends Reactive {
  constructor() {
    super();
    this.prop('persist', 'debugEvents', navigator.userAgent.indexOf('Mozilla') != -1 ? 1 : 0);
    this.prop('persist', 'notificationCloseDelay', 5000);
    this.prop('persist', 'protocols', {});
    this.prop('persist', 'wantNotifications', null);
    this.prop('ro', 'notifyPermission', () => this._notification().permission);
    this.prop('rw', 'defaultTitle', 'Convos');
    this.prop('rw', 'route', route);
    this.prop('rw', 'wsUrl', '');

    this.msgId = 0;
    this.messageCb = {};
    this.wsSendQueue = [];
  }

  notify(title, body, params = {}) {
    if (!title) title = this.defaultTitle;
    const rejectReason
      = !this.wantNotifications ? 'wantNotifications == false'
      : this._notification().permission != 'granted' ? this._notification().permission
      : !params.force && this._hasFocus() ? 'hasFocus'
      : '';

    if (rejectReason) {
      console.log('[Events:notify] Rejected: ' + rejectReason, [title, body, params]);
      return null;
    }

    // TODO: Specify icon
    const notification = this._notification(title, {...params, body});
    notification.onclick = (e) => { window.focus(); notification.close() };
    setTimeout(() => notification.close(), this.notificationCloseDelay);
    return notification;
  }

  registerProtocol(protocol, register) {
    this.protocols[protocol] = register;
    this.update({protocols: clone(this.protocols)});

    if (register && navigator.registerProtocolHandler) {
      navigator.registerProtocolHandler(protocol, this.route.baseUrl + '/register?uri=%s', 'Convos wants to handle "' + protocol + '" links');
    }

    return this;
  }

  requestPermissionToNotify(param) {
    if (typeof param == 'boolean') return this.update({wantNotifications: param});

    const notification = this._notification();
    if (notification.permission == 'granted' || !notification.requestPermission) {
      this.update({wantNotifications: notification.permission == 'granted'});
      if (param) param(notification.permission);
      return this;
    }

    notification.requestPermission(permission => {
      this.update({wantNotifications: permission == 'granted'});
      if (param) param(permission);
    });

    return this;
  }

  send(method, cb) {
    const msg = typeof method == 'string' ? {method} : {...method};
    if (!msg.method) msg.method = msg.message ? 'send' : 'ping';
    if (msg.connection) ['connection_id'].forEach(k => { msg[k] = msg.dialog[k] || '' });
    if (msg.dialog) ['connection_id', 'dialog_id'].forEach(k => { msg[k] = msg.dialog[k] || '' });
    msg.id = String(msg.method == 'ping' ? 0 : ++this.msgId);
    delete msg.connection;
    delete msg.dialog;
    if (cb) this.messageCb[msg.id] = cb;
    if (this.debugEvents) this._debug('send', msg);
    this.wsSendQueue.push(msg);
    this._ws();
  }

  start({route, wsUrl}) {
    if (route) this.update({route});
    if (wsUrl) this.update({wsUrl});
    this.keepaliveTid = setInterval(() => this._keepalive(), 10000);
    this._listenToGlobalExceptions(route);
    this._setupServiceWorker(route);
  }

  update(params) {
    const prevWantNotifications = this.wantNotifications;
    super.update(params);
    if (params.wantNotifications && !prevWantNotifications) this.notify(null, l('You have enabled notifications.'), {force: true});
    return this;
  }

  _debug(method, params) {
    if (this.debugEvents == 1 && method != 'wsEventPong' && params.method != 'ping') {
      console.log('[Events:' + (method || 'data') + ']', params);
    }
    else if (this.debugEvents >= 2) {
      console.log('[Events:' + (method || 'data') + ']', params);
    }
  }

  _dispatch(params) {
    const dispatchTo = camelize('wsEvent_' + this._getEventNameFromParam(params));
    if (this.debugEvents) this._debug(dispatchTo, params);
    if (dispatchTo != 'wsEventError') this._wsReconnectDelay = 0;

    const cb = this.messageCb[params.id];
    params.bubbles = true;
    params.dispatchTo = dispatchTo;
    params.stopPropagation = () => { params.bubbles = false };
    if (cb) cb(params);
    if (params.bubbles) this.emit('message', params);
    this.emit(dispatchTo, params);
  }

  _getEventNameFromParam(params) {
    if (params.errors) return 'error';
    if (params.event == 'state') return params.type;

    if (params.event == 'sent' && params.message.match(/\/\S+/)) {
      params.command = params.message.split(/\s+/).filter(s => s.length);
      params.command[0] = params.command[0].substring(1);
      return 'sent_' + params.command[0];
    }

    return params.event;
  }

  _hasFocus() {
    return document.hasFocus();
  }

  _keepalive() {
    this._send({method: 'ping'});
  }

  _listenToGlobalExceptions() {
    window.addEventListener('error', ({colno, error, filename, lineno, message, type, timeStamp}) => {
      this.emit('error', {type, colno, error, filename, lineno, message, timeStamp});
    });

    window.addEventListener('unhandledrejection', ({type, reason, returnValue, timeStamp}) => {
      this.emit('error', {type, reason, returnValue, timeStamp});
    });
  }

  _notification(title, params) {
    const fallback = {permission: 'denied'};

    try {
      return !window.Notification ? fallback : title ? new Notification(title, params) : Notification;
    } catch(err) {
      fallback.error = err;
      return fallback;
    }
  }

  _send(msg) {
    const ws = this.ws && this.ws.readyState == 1 && this.ws;
    if (ws) ws.send(JSON.stringify(msg));
    return !!ws;
  }

  _setupServiceWorker(route) {
    return navigator.serviceWorker && navigator.serviceWorker.register(route.urlFor('/sw.js'))
      .then(reg => this.emit('serviceWorker', reg));
  }

  _ws(action = 'dequeue') {
    this.emit(action);

    if (action == 'dequeue' && this._wsReconnectTid) {
      clearTimeout(this._wsReconnectTid);
      delete this._wsReconnectTid;
    }

    if (action == 'close') {
      this._wsReconnectDelay = this._wsReconnectDelay > 5000 ? 500 : (this._wsReconnectDelay || 0) + 500;
      if (!this._wsReconnectTid) this._wsReconnectTid = setTimeout(() => this._ws(), this._wsReconnectDelay);
      delete this.ws;
    }
    else if (this.ws) {
      this.wsSendQueue = this.wsSendQueue.filter(msg => !this._send(msg));
    }
    else if (this.wsUrl) {
      this.ws = new WebSocket(this.wsUrl);
      this.ws.onopen = () => this._ws('open');
      this.ws.onclose = () => this._ws('close');
      this.ws.onerror = () => this._ws('close');
      this.ws.onmessage = (e) => this._dispatch(JSON.parse(e.data));
    }
  }
}

export const omnibus = new Omnibus();
