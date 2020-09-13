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

  addMessage(msg) {
    this.update({unread: this.unread + 1});
    return this.addMessages('push', [msg]);
  }

  is(status) {
    return status == 'notifications' ? true : super.is(status);
  }

  // Disabled
  send() { return Promise.resolve({}) }

  _addOperations() {
    this.prop('ro', 'messagesOp', api('/api', 'notificationMessages'));
    this.prop('ro', 'setLastReadOp', api('/api', 'readNotifications'));
  }
}
