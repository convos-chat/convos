import ConnURL from '../js/ConnURL';
import Dialog from './Dialog';
import SortedMap from '../js/SortedMap';
import {extractErrorMessage} from '../js/util';

const sortDialogs = (a, b) => {
  return (a.is_private || 0) - (b.is_private || 0) || a.name.localeCompare(b.name);
};

export default class Connection extends Dialog {
  constructor(params) {
    super(params);

    this._readOnlyAttr('dialogs', new SortedMap([], {sorter: sortDialogs}));

    this._updateableAttr('on_connect_commands', params.on_connect_commands || '');
    this._updateableAttr('state', params.state || 'queued');
    this._updateableAttr('wanted_state', params.wanted_state || 'connected');
    this._updateableAttr('url', typeof params.url == 'string' ? new ConnURL(params.url) : params.url);
    this._updateableAttr('nick', params.nick || this.url.searchParams.get('nick') || '');

    this.participant(this.nick, {});
  }

  addDialog(dialogId) {
    const isPrivate = dialogId.match(/^[a-z]/i);
    this.send(isPrivate ? `/query ${dialogId}` : `/join ${dialogId}`);
  }

  ensureDialog(params) {
    let dialog = this.dialogs.get(params.dialog_id);
    if (dialog) return dialog.update(params);

    dialog = new Dialog({...params, connection_id: this.connection_id, api: this.api, events: this.events});
    dialog.on('message', params => this.emit('message', params));
    dialog.on('update', () => this.update({}));
    this._addDefaultParticipants(dialog);
    this.dialogs.set(dialog.dialog_id, dialog);
    this.update({});
    return dialog;
  }

  findDialog(params) {
    return this.dialogs.get(params.dialog_id);
  }

  is(state) {
    return this.state == state;
  }

  removeDialog(params) {
    this.dialogs.delete(params.dialog_id);
    return this.update({});
  }

  update(params) {
    if (params.url && typeof params.url == 'string') params.url = new ConnURL(params.url);
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
    const existing = this.findDialog(params);
    this.ensureDialog(params).participant(this.nick, {me: true});
    if (params.frozen) (existing || this).addMessage({message: params.frozen, vars: []}); // Add "vars:[]" to force translation
  }

  wsEventMessage(params) {
    return params.dialog_id ? this.ensureDialog(params).addMessage(params) : this.addMessage(params);
  }

  wsEventNickChange(params) {
    const nickChangeParams = {old_nick: this.nick, new_nick: params.nick, type: params.type};
    super.wsEventNickChange(nickChangeParams);
    this.dialogs.forEach(dialog => dialog.wsEventNickChange(nickChangeParams));
  }

  wsEventError(params) {
    const dialog = this.findDialog(params) || this;
    const message = extractErrorMessage(params) || 'Unknown error from %1.';
    dialog.update({errors: this.errors + 1});
    dialog.addMessage({message, type: 'error', sent: params, vars: params.command || params.message});
  }

  wsEventJoin(params) {
    const dialog = this.ensureDialog(params);
    const nick = params.nick || connection.nick;
    dialog.addMessage({message: '%1 joined.', vars: [nick]});
    dialog.participant(nick, {});
  }

  wsEventPart(params) {
    if (params.nick == this.nick) this.removeDialog(params);
  }

  wsEventQuit(params) {
    this.wsEventPart(params);
  }

  wsEventSentJoin(params) {
    this.wsEventJoin(params);
  }

  wsEventSentList(params) {
    const args = params.args || '/*/';
    this.addMessage(params.done
      ? {message: 'Found %1 of %2 dialogs from %3.', vars: [params.dialogs.length, params.n_dialogs, args]}
      : {message: 'Found %1 of %2 dialogs from %3, but dialogs are still loading.', vars: [params.dialogs.length, params.n_dialogs, args]}
    );
  }

  wsEventSentQuery(params) {
    this.ensureDialog(params);
  }

  // TODO: Reply should be shown in the active dialog instead
  wsEventSentWhois(params) {
    const channels = Object.keys(params.channels);
    let message = '%1 (%2)';
    let vars = [params.nick, params.host];

    if (params.idle_for && channels.length) {
      message += ' has been idle for %3 in %4.';
      vars.push(params.idle_for);
      vars.push(channels.join(', '));
    }
    else if (params.idle_for && !channels.length) {
      message += 'has been idle for %3, and is not active in any channels.';
      vars.push(params.idle_for);
    }
    else {
      message += 'is active in %3.';
      vars.push(channels.join(', '));
    }

    const dialog = this.findDialog(params) || this;
    dialog.addMessage({message, vars});
  }

  wsEventTopic(params) {
    this.ensureDialog(params).addMessage(params.topic
      ? {message: 'Topic changed to: %1', vars: [params.topic]}
      : {message: 'No topic is set.', vars: []}
    );
  }

  _addDefaultParticipants(dialog) {
    dialog.participant(this.nick);
    if (dialog.is_private) dialog.participant(dialog.name);
  }

  _addOperations() {
    this._readOnlyAttr('setLastReadOp', this.api.operation('setConnectionLastRead'));
    this._readOnlyAttr('messagesOp', this.api.operation('connectionMessages'));
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
