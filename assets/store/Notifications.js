import Conversation from './Conversation';
import {api} from '../js/Api';

export default class Notifications extends Conversation {
  constructor(params) {
    super({
      ...params,
      connection_id: '',
      conversation_id: 'notifications',
      name: 'Notifications',
    });
  }

  addMessages(messages, method) {
    if (!Array.isArray(messages)) {
      messages = [messages];
      this.update({unread: this.unread + 1});
    }

    this.messages.push(messages);
    return this;
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

  _skipLoad() {
    return false;
  }
}
