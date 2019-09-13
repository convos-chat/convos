import Reactive from './Reactive';
import {camelize} from '../js/util';

let msgId = 0;

export default class Events extends Reactive {
  constructor() {
    super();
    this._cb = {}; // Add logic to clean up old callbacks
    this.debug = 0;
    this._readOnlyAttr('wsUrl', Convos.wsUrl); // TODO: Should probably be input parameter
    this._updateableAttr('state', 'pending');
  }

  dispatch(params) {
    const dispatchTo = camelize('wsEvent_' + this._getEventNameFromParamw(params));
    if (this.debug) this._debug(dispatchTo, params);

    const cb = this._cb[params.id || ''];
    if (cb) cb(params);

    this.emit('message', {...params, dispatchTo});

    // Make sure we update participants list
    if (params.participants && dispatchTo != 'wsEventParticipants') {
      this.emit('message', {...params, dispatchTo: 'wsEventParticipants'});
    }
  }

  async send(msg, cb) {
    const ws = await this._ws();
    if (!msg.id && msg.method != 'ping') msg.id = ++msgId;
    if (!msg.method && msg.message) msg.method = 'send';
    if (msg.dialog) ['connection_id', 'dialog_id'].forEach(k => { msg[k] = msg.dialog[k] || '' });
    delete msg.dialog;
    if (this.debug) this._debug('send', msg);
    if (cb) this._cb[msg.id] = cb;
    ws.send(JSON.stringify(msg));
  }

  _debug(method, params) {
    if (this.debug == 1 && method != 'wsEventPong' && params.method != 'ping') {
      console.debug('[Events:' + (method || 'data') + ']', params);
    }
    else if (this.debug >= 2) {
      console.debug('[Events:' + (method || 'data') + ']', params);
    }
  }

  _getEventNameFromParamw(params) {
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

  _ping() {
    if (this.ws && this.ws.readyState == 1) this.send({method: 'ping'});
  }

  async _ws() {
    if (this._wsPromise) return this._wsPromise;
    if (this._wsReconnectTid) clearTimeout(this._wsReconnectTid);

    // Enable logging of WebSocket messages to the console
    if (!localStorage.hasOwnProperty('eventLogging')) localStorage.setItem('eventLogging', navigator.userAgent.indexOf('Mozilla') == -1 ? 0 : 1);
    this.debug = localStorage.getItem('eventLogging') ? true : false;

    const ws = new WebSocket(this.wsUrl);
    if (!this._keepaliveTid) this._keepaliveTid = setInterval(() => this._ping(), 5000);

    let handled = false;
    const p = new Promise((resolve, reject) => {
      ws.onopen = () => {
        if (![handled, (handled = true)][0]) resolve((this.ws = ws));
        //this.update({state: 'open'});
      };

      ws.onclose = (e) => {
        delete this._wsPromise;
        this._wsReconnectTid = setTimeout(() => this._ws(), 20000);
        //this.update({state: 'closed'});
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
