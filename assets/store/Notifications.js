import Dialog from './Dialog';
import {api} from '../js/Api';

export default class Notifications extends Dialog {
  constructor(params) {
    super({
      ...params,
      connection_id: '',
      dialog_id: 'notifications',
      is_private: true,
      name: 'Notifications',
    });
  }

  is(status) {
    return status == 'notifications' ? true : super.is(status);
  }

  async load(params = {}) {
    if (!this.messagesOp || this.is('loading')) return this;
    this.messagesOp.update({status: 'pending'});
    this.update({messages: []});
    await super.load();
  }

  // Disabled
  send() { return Promise.resolve({}) }

  _addOperations() {
    this.prop('ro', 'messagesOp', api('/api', 'notificationMessages'));
    this.prop('ro', 'setLastReadOp', api('/api', 'readNotifications'));
  }
}
