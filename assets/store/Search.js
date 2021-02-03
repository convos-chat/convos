import Conversation from './Conversation';
import {api} from '../js/Api';

export default class Search extends Conversation {
  constructor(params) {
    super({
      ...params,
      connection_id: '',
      conversation_id: 'search',
      name: 'Search',
    });

    this.prop('rw', 'query', '');
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

    if (!(opParams.match || '').match(/\S/)) {
      return this.messages.clear().push([{message: 'Search query "%1" does not contain anything to search for.', vars: [params.message]}]);
    }

    // Load messages
    this.update({query: opParams.match, status: 'loading'});
    this.messages.clear();
    await this.messagesOp.perform(opParams);
    const body = this.messagesOp.res.body;
    this.messages[opParams.before ? 'unshift' : 'push'](body.messages || []);

    return this.update({status: this.messagesOp.status});
  }

  send(message) {
    if (typeof message == 'string') message = {message};
    this.emit('send', message);
    return Promise.resolve(message);
  }

  _addOperations() {
    this.prop('ro', 'messagesOp', api('/api', 'searchMessages'));
    this.prop('ro', 'markAsReadOp', null);
  }

  _loadParticipants() { }
}
