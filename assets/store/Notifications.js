import Conversation from './Conversation';
import {api} from '../js/Api';

export default class Notifications extends Conversation {
  constructor(params) {
    super({
      ...params,
      connection_id: '',
      conversation_id: 'notifications',
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
    this.prop('ro', 'markAsReadOp', api('/api', 'markNotificationsAsRead'));
  }
}
