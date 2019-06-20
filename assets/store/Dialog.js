import Messages from './Messages';
import {ro} from '../js/util';

export default class Dialog {
  constructor(params) {
    Object.assign(this, params);

    ro(this, 'id', this.dialog_id || this.connection_id || '');
    ro(this, 'isDialog', this.hasOwnProperty('dialog_id'));
    ro(this, 'messages', new Messages({...params, api: this.api}));
    ro(this, 'participants', {});
    ro(this, 'subscribers', []);

    const path = [];
    if (this.connection_id) path.push(this.connection_id);
    if (this.dialog_id) path.push(this.dialog_id);
    ro(this, 'path', path.map(p => encodeURIComponent(p)).join('/'));
  }

  subscribe(cb) {
    this.subscribers.push(cb);
    cb(this);
    return () => this.subscribers.filter(i => (i != cb));
  }

  update(params) {
    Object.keys(params).forEach(param => {
      const val = param == 'url' && typeof params.url == 'string' ? new ConnURL(params.url) : params[param];
      if (param != 'id') this[param] = val;
    });

    return this._notifySubscribers();
  }

  _notifySubscribers() {
    this.subscribers.forEach(cb => cb(this));
    return this;
  }
}