import Reactive from '../js/Reactive';
import Time from '../js/Time';
import {l} from '../js/i18n';
import {md} from '../js/md';
import {sortByName} from '../js/util';
import {str2color} from '../js/util';

const modes = {o: '@'};

export default class Dialog extends Reactive {
  constructor(params) {
    super();

    const path = [];
    if (params.connection_id) path.push(params.connection_id);
    if (params.dialog_id) path.push(params.dialog_id);

    this._readOnlyAttr('api', params.api);
    this._readOnlyAttr('connection_id', params.connection_id || '');
    this._readOnlyAttr('events', params.events);
    this._readOnlyAttr('is_private', params.is_private || false);
    this._readOnlyAttr('path', path.map(p => encodeURIComponent(p)).join('/'));

    this._updateableAttr('frozen', params.frozen || '');
    this._updateableAttr('last_active', new Time(params.last_active));
    this._updateableAttr('last_read', new Time(params.last_read));
    this._updateableAttr('messages', []);
    this._updateableAttr('name', params.name || 'Unknown');
    this._updateableAttr('participants', []);
    this._updateableAttr('status', 'loading');
    this._updateableAttr('topic', params.topic || '');
    this._updateableAttr('unread', params.unread || 0);

    if (params.hasOwnProperty('dialog_id')) {
      this._readOnlyAttr('dialog_id', params.dialog_id);
      Object.defineProperty(this, 'state', {get: () => this._reactive.frozen});
    }

    this.events.on('update', this._loadParticipants.bind(this));
    this._addOperations();
  }

  addMessage(msg) {
    return this.addMessages('push', [msg]);
  }

  addMessages(method, messages) {
    for (let i = 0; i < messages.length; i++) {
      const msg = messages[i];
      if (msg.hasOwnProperty('markdown')) continue; // Already processed
      if (!msg.from) msg.from = this.connection_id || 'Convos';
      if (msg.vars) msg.message = l(msg.message, ...msg.vars);
      if (msg.highlight) this.events.notifyUser(msg.from, msg.message);

      msg.color = str2color(msg.from);
      msg.ts = new Time(msg.ts);
      msg.dayChanged = i == 0 ? false : msg.ts.getDate() != messages[i - 1].ts.getDate();
      msg.embeds = (msg.message.match(/https?:\/\/(\S+)/g) || []).map(url => url.replace(/([.!?])?$/, ''));
      msg.isSameSender = i == 0 ? false : messages[i].from == messages[i - 1].from;
      msg.markdown = md(msg.message);
    }

    switch (method) {
      case 'push': this.update({messages: this.messages.concat(messages)}); break;
      case 'set': this.update({messages}); break;
      case 'unshift': this.update({messages: messages.concat(this.messages)}); break;
    }

    this.update({status: 'loaded'});
    return this;
  }

  findParticipants(params) {
    if (!params) return this.participants;

    const needleKeys = Object.keys(params);
    const found = [];

    this.participants.forEach(participant => {
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
    return this.status == status;
  }

  async load() {
    if (!this.messagesOp || this.messagesOp.is('success')) return this;
    this.update({status: 'loading'});
    await this.messagesOp.perform(this);
    this._loadParticipants();
    return this.addMessages('set', this.messagesOp.res.body.messages || []);
  }

  async loadHistoric() {
    const first = this.messages[0];
    if (!first || first.end) return;

    this.update({status: 'loading'});
    await this.messagesOp.perform({
      before: first.ts.toISOString(),
      connection_id: this.connection_id,
      dialog_id: this.dialog_id,
    });

    const messages = this.messagesOp.res.body.messages || [];
    if (!messages.length && this.messages.length) first.endOfHistory = true;
    return this.addMessages('unshift', messsages);
  }

  participant(nick, params = {}) {
    const id = this._participantId(nick);
    params.nick = nick;

    const participant = this.participants.find(p => p.id == id);
    if (participant) {
      Object.keys(params).forEach(k => { participant[k] = params[k] });
      this.update({});
    }
    else {
      this.participants.push({...params, id, name: nick, ts: new Time()});
      this.participants.sort(sortByName);
      this.update({});
    }

    return participant;
  }

  send(message, methodName) {
    this.events.send(
      {connection_id: this.connection_id, dialog_id: this.dialog_id || '', message},
      methodName ? this[methodName].bind(this) : null,
    );
  }

  async setLastRead() {
    if (!this.setLastReadOp) return;
    await this.setLastReadOp.perform({connection_id: this.connection_id, dialog_id: this.dialog_id});
    this.update(this.setLastReadOp.res.body); // Update last_read
  }

  topicOrStatus() {
    return this.frozen || this.topic || (this.is_private ? 'Private conversation.' : 'No topic is set.');
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
    if (participant.id != oldId) this.update({participants: this.participants(p => p.id != oldId)});
    this.addMessage({message: '%1 changed nick to %2.', vars: [params.old_nick, params.new_nick]});
  }

  wsEventPart(params) {
    const participantId = this._participantId(params.nick);
    const participant = this.participants.find(p => p.id == participantId) || {};
    this.addMessage(this._partMessage(params));

    if (!participant.me) {
      this.update({participants: this.participants(p => p.id != participantId)});
    }
  }

  _addOperations() {
    this._readOnlyAttr('setLastReadOp', this.api.operation('setDialogLastRead'));
    this._readOnlyAttr('messagesOp', this.api.operation('dialogMessages'));
  }

  _loadParticipants() {
    if (!this.messagesOp || !this.messagesOp.is('success')) return;
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

  _updateParticipants(params) {
    params.stopPropagation();
    params.participants.forEach(p => this.participant(p.name, {mode: p.mode}));
  }
}
