import Reactive from '../js/Reactive';
import ReactiveList from '../store/ReactiveList.js';
import Time from '../js/Time';
import {l} from '../js/i18n';
import {md} from '../js/md';
import {str2color} from '../js/util';

const modes = {o: '@'};

export default class Dialog extends Reactive {
  constructor(params) {
    super();

    const now = new Time().toISOString();
    const path = [];
    if (params.connection_id) path.push(params.connection_id);
    if (params.dialog_id) path.push(params.dialog_id);

    this._readOnlyAttr('api', params.api);
    this._readOnlyAttr('connection_id', params.connection_id || '');
    this._readOnlyAttr('events', params.events);
    this._readOnlyAttr('is_private', params.is_private || false);
    this._readOnlyAttr('mesagesOp', this._createMessagesOp(params));
    this._readOnlyAttr('participants', new ReactiveList());
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

    this.events.on('update', this._loadParticipants.bind(this));
  }

  addMessage(msg) {
    this.update({messages: this.messages.concat(msg)});
  }

  findParticipants(params) {
    if (!params) return this.participants;

    const needleKeys = Object.keys(params);
    const found = [];

    this.participants.map(participant => {
      for (let ni = 0; ni < needleKeys.length; ni++) {
        const needleKey = params[needleKeys[ni]];
        if (params[needleKey] != participant[needleKey]) return;
      }
      found.push(participant);
    });

    return found;
  }

  is(status) {
    if (status == 'frozen') return this.frozen && true;
    if (status == 'private') return this.is_private;
    if (status == 'unread') return this.unread && true;
    return this.mesagesOp && this.mesagesOp.is(status);
  }

  async load() {
    if (!this.mesagesOp || this.mesagesOp.is('success')) return this;
    await this.mesagesOp.perform(this);
    this._loadParticipants();
    return this.update({messages: this.mesagesOp.res.body.messages || []});
  }

  async loadHistoric() {
    const first = this.messages[0];
    if (!first || first.end) return;

    await this.mesagesOp.perform({
      before: first.ts.toISOString(),
      connection_id: this.connection_id,
      dialog_id: this.dialog_id,
    });

    const messages = this.mesagesOp.res.body.messages || [];
    if (!messages.length && this.messages.length) this.messages[0].endOfHistory = true;
    this.update({messages: messages.concat(this.messages)});
  }

  participant(nick, params = {}) {
    const id = this._participantId(nick);
    params.nick = nick;

    const participant = this.participants.find(p => p.id == id);
    if (participant) {
      Object.keys(params).forEach(k => { participant[k] = params[k] });
      this.participants.update({});
    }
    else {
      this.participants.add({...params, id, name: nick, ts: new Time()});
      this.participants.sort();
    }

    return participant;
  }

  send(message, methodName) {
    this.events.send(
      {connection_id: this.connection_id, dialog_id: this.dialog_id || '', message},
      methodName ? this[methodName].bind(this) : null,
    );
  }

  update(params) {
    if (params.messages) this._processMessages(params.messages);
    if (params.url && typeof params.url == 'string') params.url = new ConnURL(params.url);
    return super.update(params);
  }

  wsEventMode(params) {
    this.participant(params.nick, {mode: params.mode});
    this.addMessage({message: '%1 got mode %2 from %3.', vars: [params.nick, params.mode, params.from]});
  }

  wsEventSentNames(params) {
    this._updateParticipants(params);

    const msg = {message: 'Participants (%1): %2', vars: []};
    const participants = this.participants.map(p => (modes[p.mode] || '') + p.name);
    if (participants.length > 1) {
      msg.message += ' and %3.';
      msg.vars[2] = participants.pop();
    }

    msg.vars[0] = participants.length;
    msg.vars[1] = participants.join(', ');
    this.addMessage(msg);
  }

  wsEventNickChange(params) {
    const oldId = this._participantId(params.old_nick);
    const participant = this.participant(params.new_nick, this.participants.find(p => p.nick == oldId) || {});
    if (participant.id != oldId) this.participants.remove({id: oldId});
    this.addMessage({message: '%1 changed nick to %2.', vars: [params.old_nick, params.new_nick]});
  }

  wsEventPart(params) {
    const participantId = this._participantId(params.nick);
    const participant = this.participants.find(p => p.id == participantId) || {};
    this.addMessage(this._partMessage(params));

    if (!participant.me) {
      this.participants.remove({id: participantId});
      this.update({});
    }
  }

  _createMessagesOp(params) {
    if (params.dialog_id) return params.api.operation('dialogMessages');
    if (params.connection_id) return params.api.operation('connectionMessages');
    return null;
  }

  _loadParticipants() {
    if (!this.mesagesOp || !this.mesagesOp.is('success')) return;
    if (!this.events.ready || this._participantsLoaded) return;
    if (this.dialog_id && !this.is('private') && !this.is('frozen')) this.send('/names', '_updateParticipants');
    this._participantsLoaded = true;
  }

  _participantId(name) {
    return name.toLowerCase();
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

  _processMessages(messages) {
    for (let i = 0; i < messages.length; i++) {
      const msg = messages[i];
      if (msg.hasOwnProperty('markdown')) continue; // Already processed
      if (!msg.from) msg.from = this.connection_id || 'Convos';
      if (msg.vars) msg.message = l(msg.message, ...msg.vars);

      msg.color = str2color(msg.from);
      msg.ts = new Time(msg.ts);
      msg.dayChanged = i == 0 ? false : msg.ts.getDate() != messages[i - 1].ts.getDate();
      msg.embeds = (msg.message.match(/https?:\/\/(\S+)/g) || []).map(url => url.replace(/([.!?])?$/, ''));
      msg.isSameSender = i == 0 ? false : messages[i].from == messages[i - 1].from;
      msg.markdown = md(msg.message);
    }
  }

  _updateParticipants(params) {
    params.stopPropagation();
    params.participants.map(p => this.participant(p.name, {mode: p.mode}));
  }
}
