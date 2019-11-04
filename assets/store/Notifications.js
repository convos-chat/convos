import Dialog from './Dialog';

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

  // Disabled
  send() { }

  _addOperations() {
    this.prop('ro', 'messagesOp', this.api.operation('notificationMessages'));
    this.prop('ro', 'setLastReadOp', this.api.operation('readNotifications'));
  }
}
