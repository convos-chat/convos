import Reactive from '../js/Reactive';
import {l} from '../js/i18n';
import {md} from '../js/md';
import {sortByName} from '../js/util';

const modes = {o: '@'};

export default class Dialog extends Reactive {
  constructor(params) {
    super();

    const op = params.dialog_id     ? params.api.operation('dialogMessages')
             : params.connection_id ? params.api.operation('connectionMessages')
             : null;

    const now = new Date().toISOString();
    const path = [];
    if (params.connection_id) path.push(params.connection_id);
    if (params.dialog_id) path.push(params.dialog_id);

    this._readOnlyAttr('api', params.api);
    this._readOnlyAttr('connection_id', params.connection_id || '');
    this._readOnlyAttr('is_private', params.is_private || false);
    this._readOnlyAttr('op', op);
    this._readOnlyAttr('participants', {});
    this._readOnlyAttr('path', path.map(p => encodeURIComponent(p)).join('/'));

    this._updateableAttr('frozen', params.frozen || '');
    this._updateableAttr('last_active', params.last_active || now);
    this._updateableAttr('last_read', params.last_read || now);
    this._updateableAttr('messages', []);
    this._updateableAttr('name', params.name || 'Unknown');
    this._updateableAttr('topic', params.topic || '');
    this._updateableAttr('unread', params.unread || 0);

    if (params.hasOwnProperty('dialog_id')) {
      this._readOnlyAttr('dialog_id', params.dialog_id);
      Object.defineProperty(this, 'state', {get: () => this._reactive.frozen});
    }
  }

  addMessage(msg) {
    this.messages.push(this._processMessage(msg));
    this.update({});
  }

  findParticipants(params) {
    const participantIds = Object.keys(this.participants).sort();
    const needleKeys = Object.keys(params);
    const found = [];

    PARTICIPANT:
    for (let pi = 0; pi < participantIds.length; pi++) {
      const participant = this.participants[participantIds[pi]];
      for (let ni = 0; ni < needleKeys.length; ni++) {
        const needleKey = params[needleKeys[ni]];
        if (params[needleKey] != participant[needleKey]) continue PARTICIPANT;
      }
      found.push(participant);
    }

    return found;
  }

  async load() {
    if (!this.op || this.loaded) return;
    await this.op.perform(this);

    const messages = (this.op.res.body.messages || []).map(msg => {
      msg.markdown = md(msg.message);
      return msg;
    });

    this.loaded = true;
    this.update({messages});
  }

  async loadHistoric() {
    const first = this.messages[0];
    if (!first || first.end) return;

    await this.op.perform({
      before: first.ts,
      connection_id: this.connection_id,
      dialog_id: this.dialog_id,
    });

    const messages = (this.op.res.body.messages || []).map(msg => this._processMessage(msg));
    if (messages.length) this.update({messages: messages.concat(this.messages)});
  }

  participant(id, params = {}) {
    if (!this.participants[id]) this.participants[id] = {ts: new Date()};
    Object.keys(params).forEach(k => { this.participants[id][k] = params[k] });
    return this.participants[id];
  }

  wsEventMode(params) {
    this.participant(params.nick, {mode: params.mode});
    this.addMessage({message: '%1 got mode %2 from %3.', vars: [params.nick, params.mode, params.from]});
  }

  wsEventNickChange(params) {
    if (!this.participants[params.old_nick]) return;
    this.participant(params.new_nick, this.participants[params.old_nick] || {});
    this.addMessage({message: '%1 changed nick to %2.', vars: [params.old_nick, params.new_nick]});
  }

  wsEventPart(params) {
    const participant = this.participants[params.nick] || {};
    this.addMessage(this._partMessage(params));

    if (!participant.me) {
      delete this.participants[params.nick];
      dialog.update({});
    }
  }

  wsEventParticipants(params) {
    const msg = {message: 'Participants: %1', vars: []};

    const participants = params.participants.sort(sortByName).map(p => {
      this.participant(p.name, p);
      return (modes[p.mode] || '') + p.name;
    });

    if (participants.length > 1) {
      msg.message += ' and %2.';
      msg.vars[1] = participants.pop();
    }

    msg.vars[0] = participants.join(', ');
    this.addMessage(msg);
  }

  _partMessage(params) {
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

  _processMessage(msg) {
    if (!msg.ts) msg.ts = new Date().toISOString();
    if (!msg.from) msg.from = this.connection_id || 'Convos';
    if (msg.vars) msg.message = l(msg.message, ...msg.vars);
    msg.markdown = md(msg.message);
    return msg;
  }
}
