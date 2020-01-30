import Reactive from './Reactive';
import {camelize} from '../js/util';
import {l} from '../js/i18n';

const Notification = window.Notification || {permission: 'denied'};

let msgId = 0;

export default class Events extends Reactive {
  constructor(params) {
    super();
    this.keepaliveTid = setInterval(() => this._send({method: 'ping'}), 10000);
    this.notificationIcon = ''; // TODO
    this.queue = [];
    this.waiting = {}; // Add logic to clean up old callbacks

    this.prop('persist', 'debugEvents', navigator.userAgent.indexOf('Mozilla') != -1 ? 1 : 0);
    this.prop('persist', 'notificationCloseDelay', 5000);
    this.prop('persist', 'wantNotifications', null);
    this.prop('ro', 'browserNotifyPermission', () => Notification.permission);
    this.prop('ro', 'wsUrl', params.wsUrl); // TODO: Should probably be input parameter
    this.prop('rw', 'ready', false);
  }

  dispatch(params) {
    const dispatchTo = camelize('wsEvent_' + this._getEventNameFromParam(params));
    if (this.debugEvents) this._debug(dispatchTo, params);

    params.bubbles = true;
    params.stopPropagation = () => { params.bubbles = false };

    const cb = this.waiting[params.id];
    if (cb) cb(params);
    if (params.bubbles) this.emit('message', {...params, dispatchTo});
  }

  listenToGlobalEvents() {
    window.addEventListener('error', ({colno, error, filename, lineno, message, type, timeStamp}) => {
      this.send({method: 'debug', type, colno, error, filename, lineno, message, timeStamp});
    });

    window.addEventListener('unhandledrejection', ({type, reason, returnValue, timeStamp}) => {
      this.send({method: 'debug', type, reason, returnValue, timeStamp});
    });
  }

  notifyUser(title, body, params = {}) {
    const rejectReason
      = !this.wantNotifications ? 'wantNotifications == false'
      : Notification.permission != 'granted' ? Notification.permission
      : !params.force && document.hasFocus() ? 'document.hasFocus'
      : '';

    if (rejectReason) {
      console.log('[Events:notifyUser] Rejected: ' + rejectReason, [title, body, params]);
      return this;
    }

    const notification = new Notification(title, {icon: this.notificationIcon, ...params, body});
    notification.onclick = (e) => { window.focus(); notification.close() };
    setTimeout(() => notification.close(), this.notificationCloseDelay);
    return this;
  }

  rejectNotifications() {
    return this.update({wantNotifications: false});
  }

  requestPermissionToNotify(cb) {
    if (Notification.permission == 'granted' || !Notification.requestPermission) {
      this.update({wantNotifications: Notification.permission == 'granted'});
      if (cb) cb(Notification.permission);
      return this;
    }

    Notification.requestPermission(permission => {
      this.update({wantNotifications: permission == 'granted'});
      if (cb) cb(permission);
    });

    return this;
  }

  send(msg, cb) {
    if (!msg.id && msg.method != 'ping') msg.id = ++msgId;
    if (!msg.method && msg.message) msg.method = 'send';
    if (msg.dialog) ['connection_id', 'dialog_id'].forEach(k => { msg[k] = msg.dialog[k] || '' });
    delete msg.dialog;
    if (this.debugEvents) this._debug('send', msg);
    if (cb) this.waiting[msg.id] = cb;
    this.queue.push(msg);
    this._ws('dequeue');
  }

  update(params) {
    super.update(params);
    if (params.wantNotifications && !this.wantNotifications) this.notifyUser('Convos', l('You have enabled notifications!'), {force: true});
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

  _send(msg) {
    const ws = this.ws && this.ws.readyState == 1 && this.ws;
    if (ws) ws.send(JSON.stringify(msg));
    return !!ws;
  }

  _ws(action) {
    if (action == 'dequeue' && this._wsReconnectTid) {
      clearTimeout(this._wsReconnectTid);
      delete this._wsReconnectTid;
    }

    if (action == 'start') {
      this._wsReconnectDelay = 0;
      this.update({ready: true});
    }

    if (action == 'stop') {
      this._wsReconnectDelay = this._wsReconnectDelay > 5000 ? 500 : (this._wsReconnectDelay || 0) + 500;
      if (!this._wsReconnectTid) this._wsReconnectTid = setTimeout(() => this._ws('dequeue'), this._wsReconnectDelay);
      this.update({ready: false});
      delete this.ws;
    }
    else if (this.ws) {
      this.queue = this.queue.filter(msg => !this._send(msg));
    }
    else {
      this.ws = new WebSocket(this.wsUrl);
      this.ws.onopen = () => this._ws('start');
      this.ws.onclose = () => this._ws('stop');
      this.ws.onerror = () => this._ws('stop');
      this.ws.onmessage = (e) => this.dispatch(JSON.parse(e.data));
    }
  }
}
