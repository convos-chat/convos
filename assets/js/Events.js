import {gotoUrl} from '../store/router';
import {sortByName} from '../js/util';

const modes = {o: '@'};

export default class Events {
  constructor({user}) {
    this.user = user;
  }

  dispatch(params) {
    const eventName = params.event == 'state' ? params.type : params.event;
    const method = 'on' + eventName.replace(/(^|_)(\w)/g, (a, b, c) => c.toUpperCase());
    if (params.participants) this.onParticipants(params);
    if (this[method]) this[method](params);
    console.log((this[method] ? '' : 'TODO: ') + 'Events.' + method + '(', params, ')');
  }

  onConnection(params) {
    const conn = this._findDialog({connection_id: params.connection_id});
    if (!conn) return;
    conn.update({frozen: params.message || '', state: params.state});
    conn.addMessage(params.message
        ? {message: 'Connection state changed to %1: %2', vars: [params.state, params.message]}
        : {message: 'Connection state changed to %1.', vars: [params.state]}
      );
  }

  onFrozen(params) {
    const conn = this._findDialog({connection_id: params.connection_id});
    const existing = this._findDialog(params);
    this._ensureDialog(params).participant(conn.nick, {me: true});
    if (params.frozen) (existing || conn).addMessage({message: params.frozen, vars: []}); // Add "vars:[]" to force translation
    if (!existing) gotoUrl(['', 'chat', params.connection_id, params.dialog_id].map(encodeURIComponent).join('/'));
  }

  onJoin(params) {
    const dialog = this._findDialog(params);
    dialog.addMessage({message: '%1 joined.', vars: [params.nick]});
    dialog.participant(params.nick, {});
  }

  onMe(params) {
    this._ensureDialog({connection_id: params.connection_id}).update({nick: params.nick});
  }

  onMessage(params) {
    this._ensureDialog(params).addMessage(params);
  }

  onMode(params) {
    if (!params.nick) return;
    const dialog = this._findDialog(params);
    dialog.participant(params.nick, {mode: params.mode});
    dialog.addMessage({message: '%1 got mode %2 from %3.', vars: [params.nick, params.mode, params.from]});
  }

  onNickChange(params) {
    const conn = this._findDialog({connection_id: params.connection_id});

    conn.dialogs().forEach(dialog => {
      if (!dialog.participants[params.old_nick]) return;
      dialog.participant(params.new_nick, dialog.participants[params.old_nick] || {});
      dialog.addMessage({message: '%1 changed nick to %2.', vars: [params.old_nick, params.new_nick]});
    });
  }

  onPart(params) {
    const dialog = this._findDialog(params);
    const participant = dialog.participants[params.nick] || {};

    dialog.addMessage(this._onPartMessage(params, {dialog}));

    if (participant.me) {
      this.user.removeDialog(params);

      // Change active conversation
      const conn = this._findDialog({connection_id: params.connection_id});
      const nextDialog = conn.dialogs().sort((a, b) => b.last_active.localeCompare(a.last_active))[0];
      const path = ['', 'chat', params.connection_id];
      if (nextDialog) path.push(nextDialog.dialog_id);
      gotoUrl(path.map(encodeURIComponent).join('/'));
    }
    else {
      delete dialog.participants[params.nick];
      dialog.update({});
    }
  }

  onParticipants(params) {
    const dialog = this._findDialog(params);
    const msg = {message: 'Participants: %1', vars: []};

    const participants = params.participants.sort(sortByName).map(p => {
      dialog.participant(p.name, p);
      return (modes[p.mode] || '') + p.name;
    });

    if (participants.length > 1) {
      msg.message += ' and %2.';
      msg.vars[1] = participants.pop();
    }

    msg.vars[0] = participants.join(', ');
    dialog.addMessage(msg);
  }

  onPong(params) {
    this.user.wsPongTimestamp = params.ts;
  }

  onTopic(params) {
    this._ensureDialog(params).addMessage(params.topic
      ? {message: 'Topic is: %1', vars: [params.topic]}
      : {message: 'No topic is set.', vars: []}
    );
  }

  onQuit(params) {
    this.onPart(params);
  }

  _ensureDialog(params) { return this.user.ensureDialog(params) }
  _findDialog(params) { return this.user.findDialog(params) }

  _onPartMessage(params) {
    const msg = {message: '%1 parted.', vars: [params.nick]};
    if (params.kicker) {
      msg.message = '%1 was kicked by %2' + (params.message ? ': %3' : '');
      msg.vars.push(params.kicked);
      msg.vars.push(params.message);
    }
    else if (params.message) {
      msg.message += ' Reason: %2';
      msg.vars.push(params.message);
    }

    return msg;
  }
}
