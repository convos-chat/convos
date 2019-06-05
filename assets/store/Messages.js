export default class Messages {
  constructor(params) {
    ['connection_id', 'dialog_id'].forEach(k => { this[k] = params[k] });
    this.messages = [];
    this.subscribers = [];
    this.op = this.dialog_id     ? params.api.operation('dialogMessages')
            : this.connection_id ? params.api.operation('connectionMessages')
            : null;
  }

  add(message) {
    this.messages.push(message);
    this._notifySubscribers();
  }

  async load() {
    if (!this.op) return;
    if (this.messages.length) return;
    await this.op.perform(this);
    this.messages = this.op.res.body.messages || [];
    this._notifySubscribers();
  }

  subscribe(cb) {
    this.subscribers.push(cb);
    cb(this.messages);
    return () => this.subscribers.filter(i => (i != cb));
  }

  _notifySubscribers() {
    this.subscribers.forEach(cb => cb(this.messages));
  }
}