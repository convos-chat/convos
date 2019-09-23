import ConnURL from '../js/ConnURL';
import Dialog from './Dialog';
import ReactiveList from '../store/ReactiveList.js';
import {extractErrorMessage} from '../js/util';

export default class Connection extends Dialog {
  constructor(params) {
    super(params);

    this._readOnlyAttr('dialogs', new ReactiveList());
    this._readOnlyAttr('privateDialogs', () => this.dialogs.filter(d => d.is_private));
    this._readOnlyAttr('publicDialogs', () => this.dialogs.filter(d => !d.is_private));

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

    if (dialog) {
      dialog.update(params);
      this.update({});
    }
    else {
      dialog = new Dialog({...params, connection_id: this.connection_id, api: this.api, events: this.events});
      dialog.on('message', params => this.emit('message', params));
      this.dialogs.add(dialog).sort();
    }

    return dialog;
  }

  findDialog(params) {
    return this.dialogs.find(dialog => dialog.dialog_id == params.dialog_id);
  }

  removeDialog(params) {
    this.dialogs.remove(d => d.dialog_id != params.dialog_id);
    return this;
  }

  update(params) {
    if (params.url && typeof params.url == 'string') params.url = new ConnURL(params.url);
    return super.update(params);
  }

  wsEventConnection(params) {
    this.update({frozen: params.message || '', state: params.state});
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
    this.dialogs.map(dialog => dialog.wsEventNickChange(params));
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
      ? {message: 'Topic is: %1', vars: [params.topic]}
      : {message: 'No topic is set.', vars: []}
    );
  }
}
