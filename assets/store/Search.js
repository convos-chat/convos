import Dialog from './Dialog';

export default class Search extends Dialog {
  constructor(params) {
    super({
      ...params,
      connection_id: '',
      dialog_id: 'search',
      is_private: true,
      name: 'Search',
    });

    this.update({status: 'success'});
  }

  is(status) {
    if (status == 'conversation') return false;
    if (status == 'search') return true;
    return super.is(status);
  }

  async load(params) {
    if (this.is('loading')) return this;

    // params = {after, before, limit, match}
    const opParams = {...params};
    opParams.match = params.match || params.message;
    if (opParams.match == undefined) opParams.match = '';

    // Find dialog
    opParams.match = opParams.match.replace(/\s*([&#]\S+)\s*/, (all, dialog_id) => {
      opParams.dialog_id = dialog_id;
      return ' ';
    }).replace(/\s*conversation:(\S+)\s*/, (all, dialog_id) => {
      opParams.dialog_id = dialog_id;
      return ' ';
    });

    opParams.match = opParams.match.trim();
    if (!opParams.match.match(/\S/)) return this;

    // Load messages
    this.update({messages: [], status: 'loading'});
    await this.messagesOp.perform(opParams);
    const body = this.messagesOp.res.body;
    this.addMessages(opParams.before ? 'unshift' : 'push', body.messages || []);
    this.update({status: this.messagesOp.status});

    return this;
  }

  send(msg) {
    return this.load({...msg, match: msg.messages});
  }

  _addOperations() {
    this.prop('ro', 'messagesOp', this.api.operation('searchMessages'));
    this.prop('ro', 'setLastReadOp', null);
  }

  _loadParticipants() { }
}
