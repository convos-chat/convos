import ConnURL from '../js/ConnURL';
import Dialog from './Dialog';
import {extractErrorMessage} from '../js/util';
import {sortByName} from '../js/util';

export default class Connection extends Dialog {
  constructor(params) {
    super(params);

    this._readOnlyAttr('privateDialogs', () => this.dialogs.filter(d => d.is_private));
    this._readOnlyAttr('publicDialogs', () => this.dialogs.filter(d => !d.is_private));

    this._updateableAttr('dialogs', []);
    this._updateableAttr('on_connect_commands', params.on_connect_commands || '');
    this._updateableAttr('state', params.state || 'queued');
    this._updateableAttr('wanted_state', params.wanted_state || 'connected');
    this._updateableAttr('url', typeof params.url == 'string' ? new ConnURL(params.url) : params.url);
    this._updateableAttr('nick', params.nick || this.url.searchParams.get('nick') || '');
  }

  addDialog(dialogId) {
    const isPrivate = dialogId.match(/^[a-z]/i);
    this.send(isPrivate ? `/query ${dialogId}` : `/join ${dialogId}`);
  }

  ensureDialog(params) {
    let dialog = this.dialogs.find(dialog => dialog.dialog_id == params.dialog_id);
    if (dialog) return dialog.update(params);

    dialog = new Dialog({...params, connection_id: this.connection_id, api: this.api, events: this.events});
    dialog.on('message', params => this.emit('message', params));
    dialog.on('update', () => this.update({}));
    this._addDefaultParticipants(dialog);
    this.dialogs.push(dialog);
    this.dialogs.sort(sortByName);
    this.update({});
    return dialog;
  }

  findDialog(params) {
    return this.dialogs.find(dialog => dialog.dialog_id == params.dialog_id);
  }

  is(state) {
    return this.state == state;
  }

  removeDialog(params) {
    return this.update({dialogs: this.dialogs.filter(d => d.dialog_id != params.dialog_id)});
  }

  update(params) {
    if (params.nick && params.nick != this.nick) this.wsEventNickChange({new_nick: params.nick, old_nick: this.nick});
    if (params.url && typeof params.url == 'string') params.url = new ConnURL(params.url);
    return super.update(params);
  }

  wsEventConnection(params) {
    this.update({frozen: params.state == 'connected' ? '' : (params.message || ''), state: params.state});
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

  wsEventJoin(params) {
    const dialog = this.findDialog(params);
    dialog.addMessage({message: '%1 joined.', vars: [params.nick]});
    dialog.participant(params.nick, {});
  }

  wsEventMessage(params) {
    return params.dialog_id ? this.ensureDialog(params).addMessage(params) : this.addMessage(params);
  }

  wsEventNickChange(params) {
    this.dialogs.forEach(dialog => dialog.wsEventNickChange(params));
  }

  wsEventError(params) {
    this.addMessage({
      message: extractErrorMessage(params) || 'Unknown error from %1.',
      vars: params.command || params.message,
    });
  }

  wsEventPart(params) {
    if (params.nick == this.nick) this.removeDialog(params);
  }

  wsEventQuit(params) {
    this.wsEventPart(params);
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
      default: return 'Connecting...';
    }
  }
}
