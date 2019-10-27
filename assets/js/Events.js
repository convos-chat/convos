import Reactive from './Reactive';
import {camelize} from '../js/util';

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

  ensureConnected() {
    this._ws('dequeue');
  }

  notifyUser(title, body, params = {}) {
    const rejectReason = this._notificationRejectReason();
    if (rejectReason) {
      if (this.debugEvents) console.log('[Events:notifyUser] ' + rejectReason, title, body, params);
      return;
    }

    const notification = new Notification(title, {icon: this.notificationIcon, ...params, body});
    notification.onclick = (e) => { notification.cancel(); window.focus() };
    setTimeout(() => notification.close(), this.notificationCloseDelay);
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
    if (params.wantNotifications) this.notifyUser('Convos', 'You have enabled notifications!');
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
      const [command, args] = params.message.split(' ', 2);
      params.args = args;
      params.command = command.substring(1);
      return 'sent_' + params.command;
    }

    return params.event;
  }

  _notificationRejectReason() {
    if (!this.wantNotifications) return 'wantNotifications == false';
    if (!window.Notification) return 'window.Notification';
    if (Notification.permission != 'granted') return Notification.permission;
    if (document.hasFocus()) return 'document.hasFocus';
    return '';
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
      this.update({ready: true});
    }

    if (action == 'stop') {
      if (!this._wsReconnectTid) this._wsReconnectTid = setTimeout(() => this._ws('dequeue'), 3000);
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
