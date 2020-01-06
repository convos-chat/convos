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

  async load(params = {}) {
    if (Object.keys(params) == 0) this.update({messages: []});
    await super.load(params);
  }

  // Disabled
  send() { }

  _addOperations() {
    this.prop('ro', 'messagesOp', this.api.operation('notificationMessages'));
    this.prop('ro', 'setLastReadOp', this.api.operation('readNotifications'));
  }
}
