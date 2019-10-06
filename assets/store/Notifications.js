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

    this._readOnlyAttr('messagesOp', params.messagesOp);
  }

  // Disabled
  async load() { }
  async loadHistoric() { }

  _addOperations() {
    this._readOnlyAttr('setLastReadOp', this.api.operation('readNotifications'));
  }
}
