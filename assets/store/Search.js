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

    this.prop('rw', 'query', null);

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
    opParams.match = opParams.match
      .replace(/\s*conversation:(\S+)\s*/, (all, dialog_id) => [' ', (opParams.dialog_id = dialog_id)][0])
      .replace(/\s*([&#]\S+)\s*/, (all, dialog_id) => [' ', (opParams.dialog_id = dialog_id)][0]);

    opParams.match = opParams.match.trim();
    if (!opParams.match.match(/\S/)) return this;

    // Load messages
    this.update({messages: [], query: opParams.match, status: 'loading'});
    await this.messagesOp.perform(opParams);
    const body = this.messagesOp.res.body;
    this.addMessages(opParams.before ? 'unshift' : 'push', body.messages || []);

    return this.update({status: this.messagesOp.status});
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
