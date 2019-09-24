import Reactive from '../js/Reactive';
import Time from '../js/Time';
import {l} from '../js/i18n';
import {md} from '../js/md';
import {q, sortByName, str2color} from '../js/util';

const modes = {o: '@'};

export default class Dialog extends Reactive {
  constructor(params) {
    super();

    const op = params.dialog_id     ? params.api.operation('dialogMessages')
             : params.connection_id ? params.api.operation('connectionMessages')
             : null;

    const now = new Time().toISOString();
    const path = [];
    if (params.connection_id) path.push(params.connection_id);
    if (params.dialog_id) path.push(params.dialog_id);

    this._readOnlyAttr('api', params.api);
    this._readOnlyAttr('connection_id', params.connection_id || '');
    this._readOnlyAttr('events', params.events);
    this._readOnlyAttr('is_private', params.is_private || false);
    this._readOnlyAttr('op', op);
    this._readOnlyAttr('participants', {});
    this._readOnlyAttr('path', path.map(p => encodeURIComponent(p)).join('/'));

    this._updateableAttr('frozen', params.frozen || '');
    this._updateableAttr('last_active', params.last_active || now);
    this._updateableAttr('last_read', params.last_read || now);
    this._updateableAttr('loaded', false);
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
    this.update({messages: this.messages.concat(msg)});
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

  is(status) {
    if (status == 'frozen') return this.frozen && true;
    if (status == 'private') return this.is_private;
    if (status == 'unread') return this.unread && true;
    return this.mesagesOp && this.mesagesOp.is(status);
  }

  async load() {
    if (!this.op || this.loaded) return;
    await this.op.perform(this);
    this.update({loaded: true, messages: this.op.res.body.messages || []});
  }

  async loadEmbeds(message) {
    for (let i = 0; i < message.embeds.length; i++) {
      const embed = message.embeds[i];
      if (embed.el || embed.op) continue;

      embed.op = this.api.operation('embed', {}, {raw: true});
      await embed.op.perform(embed);

      let html = embed.op.res.body.html;
      if (!html) continue;
      if (!html.match(/<a.*href/)) html = `<a href="${embed.url}">${html}</a>`;

      embed.el = document.createElement('div');
      embed.el.className = 'message_embed';
      embed.el.innerHTML = html;
      embed.provider = (embed.op.res.body.provider_name || '').toLowerCase();
      delete embed.op;

      q(embed.el, 'a', aEl => { aEl.target = '_blank' });
    }
  }

  async loadHistoric() {
    const first = this.messages[0];
    if (!first || first.end) return;

    await this.op.perform({
      before: first.ts,
      connection_id: this.connection_id,
      dialog_id: this.dialog_id,
    });

    const messages = this.op.res.body.messages || [];
    if (!messages.length && this.messages.length) this.messages[0].endOfHistory = true;
    this.update({messages: messages.concat(this.messages)});
  }

  participant(id, params = {}) {
    if (!this.participants[id]) this.participants[id] = {ts: new Time()};
    Object.keys(params).forEach(k => { this.participants[id][k] = params[k] });
    return this.participants[id];
  }

  send(message) {
    this.events.send({connection_id: this.connection_id, dialog_id: this.dialog_id || '', message});
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
      this.update({});
    }
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
      if (msg.dt) continue; // Already processed
      if (!msg.ts) msg.ts = new Time().toISOString();
      if (!msg.from) msg.from = this.connection_id || 'Convos';
      if (msg.vars) msg.message = l(msg.message, ...msg.vars);

      msg.color = str2color(msg.from);
      msg.dt = new Time(msg.ts);
      msg.dayChanged = i == 0 ? false : msg.dt.getDate() != messages[i - 1].dt.getDate();
      msg.isSameSender = i == 0 ? false : messages[i].from == messages[i - 1].from;
      msg.markdown = md(msg.message);

      msg.embeds = (msg.message.match(/https:\/\/(\S+)/g) || []).map(url => {
        return {url: url.replace(/([.!?])?$/, '')};
      });
    }
  }
}
