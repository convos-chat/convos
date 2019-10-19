import Reactive from './Reactive';
import {camelize} from '../js/util';

let msgId = 0;

export default class Events extends Reactive {
  constructor() {
    super();
    this.notificationIcon = ''; // TODO
    this.queue = [];
    this.waiting = {}; // Add logic to clean up old callbacks

    this._localStorageAttr('notificationCloseDelay', 5000);
    this._localStorageAttr('debugEvents', navigator.userAgent.indexOf('Mozilla') != -1 ? 1 : 0);
    this._localStorageAttr('wantNotifications', false);
    this._readOnlyAttr('wsUrl', Convos.wsUrl); // TODO: Should probably be input parameter
    this._updateableAttr('ready', false);
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
    this._dequeue();
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

  _dequeue() {
    // Send messages in the queue
    this.queue = this.queue.filter(msg => !this._send(msg));

    // Do not connect unless we are disconnected and have queued messages
    if (this.queue.length == 0 || this.ws) return;

    // Make sure the connection does not turn inactive
    if (!this._keepaliveTid) this._keepaliveTid = setInterval(() => this._send({method: 'ping'}), 10000);

    // Cancel scheduled reconnect
    if (this._wsReconnectTid) clearTimeout(this._wsReconnectTid);
    delete this._wsReconnectTid;

    // Connect and keep track of connection state
    this.ws = new WebSocket(this.wsUrl);
    this.ws.onopen = () => {
      this.update({ready: true});
      this._dequeue();
    };

    this.ws.onclose = this._reconnect.bind(this);
    this.ws.onerror = this._reconnect.bind(this);
    this.ws.onmessage = (e) => this.dispatch(JSON.parse(e.data));
  }

  _reconnect(e) {
    if (!this._wsReconnectTid) this._wsReconnectTid = setTimeout(() => this._dequeue(), 5000);
    this.update({ready: false});
    this.ws = null;
  }

  _send(msg) {
    const ws = this.ws && this.ws.readyState == 1 && this.ws;
    if (ws) ws.send(JSON.stringify(msg));
    return !!ws;
  }
}
