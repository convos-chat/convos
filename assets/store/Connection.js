import ConnURL from '../js/ConnURL';
import Dialog from './Dialog';
import SortedMap from '../js/SortedMap';
import {extractErrorMessage} from '../js/util';
import {api} from '../js/Api';
import {modeMoniker} from '../js/constants';

const sortDialogs = (a, b) => {
  return (a.is_private || 0) - (b.is_private || 0) || a.name.localeCompare(b.name);
};

export default class Connection extends Dialog {
  constructor(params) {
    super(params);

    this.prop('ro', 'dialogs', new SortedMap([], {sorter: sortDialogs}));
    this.prop('rw', 'on_connect_commands', params.on_connect_commands || '');
    this.prop('rw', 'state', params.state || 'queued');
    this.prop('rw', 'wanted_state', params.wanted_state || 'connected');
    this.prop('rw', 'url', typeof params.url == 'string' ? new ConnURL(params.url) : params.url || new ConnURL('convos://loopback'));

    const me = params.me || {};
    const nick = me.nick || this.url.searchParams.get('nick') || '';
    this.prop('rw', 'nick', nick);
    this.prop('rw', 'real_host', me.real_host || this.url.hostname);
    this.prop('rw', 'server_op', me.server_op || false);
    this.participants([{nick}]);
  }

  ensureDialog(params) {
    let dialog = this.dialogs.get(params.dialog_id);
    if (dialog) return dialog.update(params);

    dialog = new Dialog({...params, connection_id: this.connection_id});
    dialog.on('message', params => this.emit('message', params));
    dialog.on('update', () => this.update({dialogs: true}));
    this._addDefaultParticipants(dialog);
    this.dialogs.set(dialog.dialog_id, dialog);
    this.update({dialogs: true});
    this.emit('dialogadd', dialog);
    return dialog;
  }

  findDialog(params) {
    return this.dialogs.get(params.dialog_id) || null;
  }

  is(status) {
    return this.state == status || super.is(status);
  }

  removeDialog(params) {
    const dialog = this.findDialog(params) || params;
    this.dialogs.delete(dialog.dialog_id);
    this.emit('dialogremove', dialog);
    return this.update({dialogs: true});
  }

  send(message, methodName) {
    if (typeof message == 'string') message = {message};
    if (message.message.indexOf('/') != 0) message.message = '/quote ' + message.message;
    return super.send(message, methodName);
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
    const wasFrozen = existing && existing.frozen;
    this.ensureDialog(params).participants([{nick: this.nick, me: true}]);
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
    return params.dialog_id ? this.ensureDialog(params).addMessage(params) : this.addMessage(params);
  }

  wsEventNickChange(params) {
    const nickChangeParams = {old_nick: params.old_nick || this.nick, new_nick: params.new_nick || params.nick, type: params.type};
    if (params.old_nick == this.nick) nickChangeParams.me = true;
    super.wsEventNickChange(nickChangeParams);
    this.dialogs.forEach(dialog => dialog.wsEventNickChange(nickChangeParams));
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
    if (joinCommand) return this.ensureDialog({...params, dialog_id: joinCommand[2]});

    // Generic errors
    const dialog = (params.dialog_id && params.frozen) ? this.ensureDialog(params) : (this.findDialog(params) || this);
    dialog.update({errors: this.errors + 1});
    dialog.addMessage(msg);
  }

  wsEventJoin(params) {
    const dialog = this.ensureDialog(params);
    const nick = params.nick || this.nick;
    if (nick != this.nick) dialog.addMessage({message: '%1 joined.', vars: [nick]});
    dialog.participants([{nick}]);
  }

  wsEventPart(params) {
    if (params.nick == this.nick) return this.removeDialog(params);
    if (params.dialog_id) return;
    this.dialogs.forEach(dialog => dialog.wsEventPart(params));
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
      ? {message: 'Found %1 of %2 dialogs from %3.', vars: [params.dialogs.length, params.n_dialogs, args]}
      : {message: 'Found %1 of %2 dialogs from %3, but dialogs are still loading.', vars: [params.dialogs.length, params.n_dialogs, args]}
    );
  }

  wsEventSentMode(params) {
    const dialog = this.findDialog(params) || this;

    const modeSent = (params.command[1] || '').match(/(\W*)(\w)$/);
    if (!modeSent) return console.log('[wsEventSentMode] Unable to handle message:', params);
    modeSent.shift();

    switch (modeSent[1]) {
      case '':
        return dialog.addMessage({message: '%s has mode %s', vars: [params.dialog_id, params.mode]});
      case 'k':
        return dialog.addMessage({message: modeSent[0] == '+' ? 'Key was set.' : 'Key was unset.'});
      case 'b':
        return this._wsEventSentModeB(params, modeSent);
    }
  }

  _wsEventSentModeB(params, modeSent) {
    const dialog = this.findDialog(params) || this;

    if (params.banlist) {
      if (!params.banlist.length) dialog.addMessage({message: 'Ban list is empty.'});
      params.banlist.forEach(ban => {
        dialog.addMessage({message: 'Ban mask %1 set by %2 at %3.', vars: [ban.mask, ban.by, new Date(ban.ts * 1000).toLocaleString()]});
      });
    }
    else {
      const action = modeSent[0] == '+' ? 'set' : 'removed';
      dialog.addMessage({message: `Ban mask %1 ${action}.`, vars: [params.command[2]]});
    }
  }

  wsEventSentQuery(params) {
    this.ensureDialog(params);
  }

  // TODO: Reply should be shown in the active dialog instead
  wsEventSentWhois(params) {
    let message = '%1 (%2)';
    let vars = [params.nick, params.host];

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

    const dialog = this.findDialog(params) || this;
    dialog.addMessage({message, vars, sent: params});
  }

  _addDefaultParticipants(dialog) {
    const participants = [{nick: this.nick, me: true}];
    if (dialog.is_private) participants.push({nick: dialog.name});
    dialog.participants(participants);
  }

  _addOperations() {
    this.prop('ro', 'setLastReadOp', api('/api', 'setConnectionLastRead'));
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
