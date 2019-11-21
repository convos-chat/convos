import Reactive from '../js/Reactive';
import SortedMap from '../js/SortedMap';
import Time from '../js/Time';
import {channelModeCharToModeName, userModeCharToModeName} from '../js/constants';
import {l} from '../js/i18n';
import {md} from '../js/md';
import {str2color} from '../js/util';

const channelRe = new RegExp('^[#&]');
const humanMode = {o: '@', v: '+'};

const sortParticipants = (a, b) => {
  return b.modes.operator || false - a.modes.operator || false
      || b.modes.voice || false - a.modes.voice || false
      || a.name.localeCompare(b.name);
};

export default class Dialog extends Reactive {
  constructor(params) {
    super();

    const path = ['', 'chat'];
    if (params.connection_id) path.push(params.connection_id);
    if (params.dialog_id) path.push(params.dialog_id);

    // TODO: Figure out why this happens for some users
    if (params.connection_id && !params.name) {
      console.trace('[Convos] Invalid params was passed on to new Dialog(', params, ')');
    }

    this.prop('ro', '_participants', new SortedMap([], {sorter: sortParticipants}));
    this.prop('ro', 'api', params.api);
    this.prop('ro', 'color', str2color(params.dialog_id || params.connection_id || ''));
    this.prop('ro', 'connection_id', params.connection_id || '');
    this.prop('ro', 'events', params.events);
    this.prop('ro', 'is_private', () => this.dialog_id && !channelRe.test(this.name));
    this.prop('ro', 'path', path.map(p => encodeURIComponent(p)).join('/'));

    this.prop('rw', 'errors', 0);
    this.prop('rw', 'last_active', new Time(params.last_active));
    this.prop('rw', 'last_read', new Time(params.last_read));
    this.prop('rw', 'messages', []);
    this.prop('rw', 'modes', {});
    this.prop('rw', 'name', params.name || params.dialog_id || '#unknown');
    this.prop('rw', 'status', 'pending');
    this.prop('rw', 'topic', params.topic || '');
    this.prop('rw', 'unread', params.unread || 0);

    if (params.hasOwnProperty('dialog_id')) {
      this.prop('ro', 'dialog_id', params.dialog_id);
      this.prop('rw', 'frozen', params.frozen || '');
    }
    else {
      this.prop('ro', 'frozen', () => this._calculateFrozen());
    }

    if (params.dialog_id) {
      this.prop('persist', 'wantNotifications', false, {key: params.dialog_id +  ':wantNotifications', lazy: true});
    }

    this._addOperations();
  }

  addMessage(msg) {
    if (msg.from && ['action', 'error', 'private'].indexOf(msg.type) != -1) {
      if (msg.highlight || this.is_private || this.wantNotifications) {
        const title = msg.from == this.name ? msg.from : l('%1 in %2', msg.from, this.name);
        this.events.notifyUser(title, msg.message);
      }

      this.update({unread: this.unread + 1});
    }

    return this.addMessages('push', [msg]);
  }

  addMessages(method, messages) {
    let start = 0;
    let stop = messages.length;

    switch (method) {
      case 'push':
        start = this.messages.length;
        messages = this.messages.concat(messages);
        stop = messages.length;
        break;
      case 'unshift':
        messages = messages.concat(this.messages);
        break;
    }

    for (let i = start; i < stop; i++) {
      const msg = messages[i];
      if (msg.hasOwnProperty('markdown')) continue; // Already processed
      if (!msg.from) msg.from = this.connection_id || 'Convos';
      if (!msg.type) msg.type = 'notice'; // TODO: Is this a good default?
      if (msg.vars) msg.message = l(msg.message, ...msg.vars);

      msg.color = str2color(msg.from.toLowerCase());
      msg.ts = new Time(msg.ts);
      msg.dayChanged = i == 0 ? false : msg.ts.getDate() != messages[i - 1].ts.getDate();
      msg.embeds = (msg.message.match(/https?:\/\/(\S+)/g) || []).map(url => url.replace(/(\W)?$/, ''));
      msg.fromId = msg.from.toLowerCase();
      msg.isSameSender = i == 0 ? false : messages[i].from == messages[i - 1].from;
      msg.markdown = md(msg.message);
    }

    this.update({messages});
    return this;
  }

  is(status) {
    if (status == 'frozen') return this.frozen && true;
    if (status == 'private') return this.is_private;
    if (status == 'unread') return this.unread && true;
    return this.status == status;
  }

  async load({before}) {
    if (!this.messagesOp || this.is('loading')) return this;

    const opParams = {connection_id: this.connection_id, dialog_id: this.dialog_id};
    if (before && before.endOfHistory) return;
    if (before && before.ts) before = before.ts.toISOString();
    if (before) opParams.before = before;

    this.update({status: 'loading'});
    await this.messagesOp.perform(opParams);

    const body = this.messagesOp.res.body;
    this.addMessages('unshift', body.messages || []);
    this.update({status: this.messagesOp.status});
    if (body.end && this.messages.length) this.messages[0].endOfHistory = true;

    return this;
  }

  findParticipant(nick) {
    return this._participants.get(this._participantId(typeof nick == 'undefined' ? '' : nick));
  }

  participants(participants = []) {
    participants.forEach(p => {
      if (!p.nick) p.nick = p.name; // TODO: Just use "name"?
      const id = this._participantId(p.nick);
      const existing = this._participants.get(id);

      if (existing) {
        Object.keys(p).forEach(k => { existing[k] = p[k] });
        p = existing;
      }

      if (!p.modes) p.modes = {};
      this._calculateModes(userModeCharToModeName, p.mode, p.modes);
      delete p.mode;

      this._participants.set(id, {name: p.nick, ...p, color: str2color(id), id, ts: new Time()});
    });

    if (participants.length) this.update({force: true});

    return this._participants.toArray();
  }

  send(message, methodName) {
    this.events.send(
      {connection_id: this.connection_id, dialog_id: this.dialog_id || '', message},
      methodName ? this[methodName].bind(this) : null,
    );
  }

  async setLastRead() {
    if (!this.setLastReadOp) return;
    this.update({errors: 0, unread: 0});
    await this.setLastReadOp.perform({connection_id: this.connection_id, dialog_id: this.dialog_id});
    this.update(this.setLastReadOp.res.body || {}); // Update last_read
  }

  update(params) {
    this._loadParticipants();
    return super.update(params);
  }

  wsEventMode(params) {
    if (params.nick) {
      this.participants([{nick: params.nick, mode: params.mode}]);
      this.addMessage({message: '%1 got mode %2 from %3.', vars: [params.nick, params.mode, params.from]});
    }
    else {
      this.update({modes: this._calculateModes(channelModeCharToModeName, params.mode, this.modes)});
    }
  }

  wsEventNickChange(params) {
    const oldId = this._participantId(params.old_nick);
    if (!this._participants.has(oldId)) return;
    if (params.old_nick == params.new_nick) return;
    this._participants.delete(oldId);
    const message = params.type == 'me' ? 'You (%1) changed nick to %2.' : '%1 changed nick to %2.';
    this.addMessage({message, vars: [params.old_nick, params.new_nick]});
  }

  wsEventPart(params) {
    const participant = this.findParticipant(params.nick);
    if (!participant || participant.me) return;
    this._participants.delete(this._participantId(params.nick));
    this.update({force: true});
    this.addMessage(this._partMessage(params));
  }

  wsEventSentNames(params) {
    this._updateParticipants(params);

    const msg = {message: 'Participants (%1): %2', vars: []};
    const participants = this._participants.map(p => (humanMode[p.mode] || '') + p.name);
    if (participants.length > 1) {
      msg.message += ' and %3.';
      msg.vars[2] = participants.pop();
    }

    msg.vars[0] = participants.length;
    msg.vars[1] = participants.join(', ');
    this.addMessage(msg);
  }

  _addOperations() {
    this.prop('ro', 'messagesOp', this.api.operation('dialogMessages'));
    this.prop('ro', 'setLastReadOp', this.api.operation('setDialogLastRead'));
  }

  _calculateModes(modeMap, modeStr, target) {
    const [all, addRemove, modeList] = (modeStr || '').match(/^(\+|-)?(.*)/) || ['', '+', ''];
    modeList.split('').forEach(char => {
      target[modeMap[char] || char] = addRemove != '-';
    });
  }

  _calculateFrozen() {
    return '';
  }

  _loadParticipants() {
    if (this.participantsLoaded || !this.dialog_id || !this.messagesOp) return;
    if (this.is('frozen') || !this.messagesOp.is('success')) return;
    this.participantsLoaded = true;
    return this.is_private ? this.send('/ison', '_noop') : this.send('/names', '_updateParticipants');
  }

  _noop() {
  }

  _participantId(name) {
    return name.toLowerCase();
  }

  _partMessage(params) {
    const msg = {message: '%1 parted.', vars: [params.nick]};
    if (params.kicker) {
      msg.message = '%1 was kicked by %2' + (params.message ? ': %3' : '');
      msg.vars.push(params.kicker);
      msg.vars.push(params.message);
    }
    else if (params.message) {
      msg.message += ' Reason: %2';
      msg.vars.push(params.message);
    }

    return msg;
  }

  _updateParticipants(params) {
    this._participants.clear();
    this.participants(params.participants);
    params.stopPropagation();
  }
}
