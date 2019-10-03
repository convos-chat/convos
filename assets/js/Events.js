import Reactive from './Reactive';
import {camelize} from '../js/util';

let msgId = 0;

export default class Events extends Reactive {
  constructor() {
    super();
    this.notificationIcon = ''; // TODO
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

  async send(msg, cb) {
    const ws = await this._ws();
    if (!msg.id && msg.method != 'ping') msg.id = ++msgId;
    if (!msg.method && msg.message) msg.method = 'send';
    if (msg.dialog) ['connection_id', 'dialog_id'].forEach(k => { msg[k] = msg.dialog[k] || '' });
    delete msg.dialog;
    if (this.debugEvents) this._debug('send', msg);
    if (cb) this.waiting[msg.id] = cb;
    ws.send(JSON.stringify(msg));
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
    if (Notification.permission != 'granted') return Notification.permission;
    if (document.hasFocus()) return 'document.hasFocus';
    return '';
  }

  _ping() {
    if (this.ws && this.ws.readyState == 1) this.send({method: 'ping'});
  }

  async _ws() {
    if (this._wsPromise) return this._wsPromise;
    if (this._wsReconnectTid) clearTimeout(this._wsReconnectTid);

    const ws = new WebSocket(this.wsUrl);
    if (!this._keepaliveTid) this._keepaliveTid = setInterval(() => this._ping(), 5000);

    let handled = false;
    const p = new Promise((resolve, reject) => {
      ws.onopen = () => {
        if (![handled, (handled = true)][0]) resolve((this.ws = ws));
        this.update({ready: true});
      };

      ws.onclose = (e) => {
        delete this._wsPromise;
        this._wsReconnectTid = setTimeout(() => this._ws(), 20000);
        this.update({ready: false});
        if (![handled, (handled = true)][0]) reject(e);
      };

      ws.onerror = (e) => {
        if (![handled, (handled = true)][0]) reject(e);
      };

      ws.onmessage = (e) => this.dispatch(JSON.parse(e.data));
    });

    return (this._wsPromise = p);
  }
}
