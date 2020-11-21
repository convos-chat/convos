import ConnectionURL from '../js/ConnectionURL';
import Conversation from './Conversation';
import SortedMap from '../js/SortedMap';
import {extractErrorMessage} from '../js/util';
import {api} from '../js/Api';
import {modeMoniker} from '../js/constants';

const sortConversations = (a, b) => {
  return (a.is_private || 0) - (b.is_private || 0) || a.name.localeCompare(b.name);
};

export default class Connection extends Conversation {
  constructor(params) {
    super(params);

    this.prop('ro', 'conversations', new SortedMap([], {sorter: sortConversations}));
    this.prop('rw', 'on_connect_commands', params.on_connect_commands || '');
    this.prop('rw', 'state', params.state || 'queued');
    this.prop('rw', 'wanted_state', params.wanted_state || 'connected');
    this.prop('rw', 'url', typeof params.url == 'string' ? new ConnectionURL(params.url) : params.url || new ConnectionURL('convos://loopback'));

    const me = params.me || {};
    const nick = me.nick || this.url.searchParams.get('nick') || '';
    this.prop('rw', 'nick', nick);
    this.prop('rw', 'real_host', me.real_host || this.url.hostname);
    this.prop('rw', 'server_op', me.server_op || false);
    this.participants([{nick}]);
  }

  ensureConversation(params) {
    let conversation = this.conversations.get(params.conversation_id);
    if (conversation) return conversation.update(params);

    conversation = new Conversation({...params, connection_id: this.connection_id});
    conversation.on('message', params => this.emit('message', params));
    conversation.on('update', () => this.update({conversations: true}));
    this._addDefaultParticipants(conversation);
    this.conversations.set(conversation.conversation_id, conversation);
    this.update({conversations: true});
    this.emit('conversationadd', conversation);
    return conversation;
  }

  findConversation(params) {
    return this.conversations.get(params.conversation_id) || null;
  }

  is(status) {
    return this.state == status || super.is(status);
  }

  removeConversation(params) {
    const conversation = this.findConversation(params) || params;
    this.conversations.delete(conversation.conversation_id);
    this.emit('conversationremove', conversation);
    return this.update({conversations: true});
  }

  send(message) {
    if (typeof message == 'string') message = {message};
    if (message.message.indexOf('/') != 0) message.message = '/quote ' + message.message;
    return super.send(message);
  }

  update(params) {
    if (params.url && typeof params.url == 'string') params.url = new ConnectionURL(params.url);
    return super.update(params);
  }

  wsEventConnection(params) {
    this.update({state: params.state});
    this.addMessage(params.message
        ? {message: 'Connection state changed to %1: %2', vars: [params.state, params.message]}
        : {message: 'Connection state changed to %1.', vars: [params.state]}
      );
  }

  wsEventFrozen(params) {
    const existing = this.findConversation(params);
    const wasFrozen = existing && existing.frozen;
    this.ensureConversation(params).participants([{nick: this.nick, me: true}]);
    if (params.frozen) (existing || this).addMessage({message: params.frozen, vars: []}); // Add "vars:[]" to force translation
    if (wasFrozen && !params.frozen) existing.addMessage({message: 'Connected.', vars: []});
  }

  wsEventMe(params) {
    this.wsEventNickChange(params);
    if (params.server_op) this.addMessage({message: 'You are an IRC operator.', vars: [], highlight: true});
    this.update(params);
  }

  wsEventMessage(params) {
    params.yourself = params.from == this.nick;
    return params.conversation_id ? this.ensureConversation(params).addMessage(params) : this.addMessage(params);
  }

  wsEventNickChange(params) {
    const nickChangeParams = {old_nick: params.old_nick || this.nick, new_nick: params.new_nick || params.nick, type: params.type};
    if (params.old_nick == this.nick) nickChangeParams.me = true;
    super.wsEventNickChange(nickChangeParams);
    this.conversations.forEach(conversation => conversation.wsEventNickChange(nickChangeParams));
  }

  wsEventError(params) {
    const msg = {
      message: extractErrorMessage(params) || params.frozen || 'Unknown error from %1.',
      sent: params,
      type: 'error',
      vars: params.command || [params.message],
    };

    // Could not join
    const joinCommand = (params.message || '').match(/^\/j(oin)? (\S+)/);
    if (joinCommand) return this.ensureConversation({...params, conversation_id: joinCommand[2]});

    // Generic errors
    const conversation = (params.conversation_id && params.frozen) ? this.ensureConversation(params) : (this.findConversation(params) || this);
    conversation.update({errors: this.errors + 1});
    conversation.addMessage(msg);
  }

  wsEventJoin(params) {
    const conversation = this.ensureConversation(params);
    const nick = params.nick || this.nick;
    if (nick != this.nick) conversation.addMessage({message: '%1 joined.', vars: [nick]});
    conversation.participants([{nick}]);
  }

  wsEventPart(params) {
    if (params.nick == this.nick) return this.removeConversation(params);
    if (params.conversation_id) return;
    this.conversations.forEach(conversation => conversation.wsEventPart(params));
  }

  wsEventQuit(params) {
    this.wsEventPart(params);
  }

  // A connection cannot handle WebRTC events
  wsEventRtc(params) { }

  wsEventSentJoin(params) {
    this.wsEventJoin(params);
  }

  wsEventSentList(params) {
    const args = params.args || '/*/';
    this.addMessage(params.done
      ? {message: 'Found %1 of %2 conversations from %3.', vars: [params.conversations.length, params.n_conversations, args]}
      : {message: 'Found %1 of %2 conversations from %3, but conversations are still loading.', vars: [params.conversations.length, params.n_conversations, args]}
    );
  }

  wsEventSentMode(params) {
    const conversation = this.findConversation(params) || this;

    const modeSent = (params.command[1] || '').match(/(\W*)(\w)$/);
    if (!modeSent) return console.log('[wsEventSentMode] Unable to handle message:', params);
    modeSent.shift();

    switch (modeSent[1]) {
      case '':
        return conversation.addMessage({message: '%s has mode %s', vars: [params.conversation_id, params.mode]});
      case 'k':
        return conversation.addMessage({message: modeSent[0] == '+' ? 'Key was set.' : 'Key was unset.'});
      case 'b':
        return this._wsEventSentModeB(params, modeSent);
    }
  }

  _wsEventSentModeB(params, modeSent) {
    const conversation = this.findConversation(params) || this;

    if (params.banlist) {
      if (!params.banlist.length) conversation.addMessage({message: 'Ban list is empty.'});
      params.banlist.forEach(ban => {
        conversation.addMessage({message: 'Ban mask %1 set by %2 at %3.', vars: [ban.mask, ban.by, new Date(ban.ts * 1000).toLocaleString()]});
      });
    }
    else {
      const action = modeSent[0] == '+' ? 'set' : 'removed';
      conversation.addMessage({message: `Ban mask %1 ${action}.`, vars: [params.command[2]]});
    }
  }

  wsEventSentQuery(params) {
    this.ensureConversation(params);
  }

  wsEventSentWhois(params) {
    let message = '%1 (%2@%3, %4)';
    let vars = [params.nick, params.user, params.host, params.name];

    const channels = Object.keys(params.channels).sort().map(name => (modeMoniker[params.channels[name].mode] || '') + name);
    params.channels = channels;

    if (params.idle_for && channels.length) {
      message += ' has been idle for %3s in %4.';
      vars.push(params.idle_for);
      vars.push(channels.join(', '));
    }
    else if (params.idle_for && !channels.length) {
      message += 'has been idle for %3s, and is not in any channels.';
      vars.push(params.idle_for);
    }
    else if (channels.length) {
      message += ' is active in %3.';
      vars.push(channels.join(', '));
    }
    else {
      message += ' is not in any channels.';
    }

    const conversation = this.findConversation(params) || this;
    conversation.addMessage({message, vars, sent: params});
  }

  _addDefaultParticipants(conversation) {
    const participants = [{nick: this.nick, me: true}];
    if (conversation.is_private) participants.push({nick: conversation.name});
    conversation.participants(participants);
  }

  _addOperations() {
    this.prop('ro', 'markAsReadOp', api('/api', 'markConnectionAsRead'));
    this.prop('ro', 'messagesOp', api('/api', 'connectionMessages'));
  }

  _calculateFrozen() {
    switch (this.state) {
      case 'connected': return '';
      case 'disconnected': return 'Disconnected.';
      case 'unreachable': return 'Unreachable.';
      default: return 'Connecting...';
    }
  }
}
