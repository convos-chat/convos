import Conversation from './Conversation';
import {convosApi} from '../js/Api';

export default class Notifications extends Conversation {
  constructor(params) {
    super({
      ...params,
      connection_id: '',
      conversation_id: 'notifications',
      name: 'Notifications',
    });
  }

  addMessages(messages) {
    if (!Array.isArray(messages)) {
      messages = [messages];
    }

    this.messages.push(messages);
    return this;
  }

  async markAsRead() {
    await super.markAsRead();
    this.emit('cleared');
    return this;
  }

  is(status) {
    return status === 'notifications' ? true : super.is(status);
  }

  // Disabled
  send(params = {}) { return Promise.resolve(params) }

  _addOperations() {
    this.prop('ro', 'markAsReadOp', convosApi.op('markNotificationsAsRead'));
    this.prop('ro', 'messagesOp', convosApi.op('notificationMessages'));
  }

  _skipLoad() {
    return false;
  }
}
