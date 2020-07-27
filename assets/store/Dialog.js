import Reactive from '../js/Reactive';
import SortedMap from '../js/SortedMap';
import Time from '../js/Time';
import {api} from '../js/Api';
import {camelize, isType, str2color} from '../js/util';
import {channelModeCharToModeName, modeMoniker, userModeCharToModeName} from '../js/constants';
import {l} from '../js/i18n';
import {md} from '../js/md';
import {notify} from '../js/Notify';
import {route} from '../store/Route';
import {getSocket} from '../js/Socket';

const channelRe = new RegExp('^[#&]');

const sortParticipants = (a, b) => {
  return b.modes.operator || false - a.modes.operator || false
      || b.modes.voice || false - a.modes.voice || false
      || a.name.localeCompare(b.name);
};

let nMessages = 0;

export default class Dialog extends Reactive {
  constructor(params) {
    super();

    this.prop('ro', '_participants', new SortedMap([], {sorter: sortParticipants}));
    this.prop('ro', 'color', str2color(params.dialog_id || params.connection_id || ''));
    this.prop('ro', 'connection_id', params.connection_id || '');
    this.prop('ro', 'is_private', () => this.dialog_id && !channelRe.test(this.name));
    this.prop('ro', 'path', route.dialogPath(params));

    this.prop('rw', 'errors', 0);
    this.prop('rw', 'first_time', false);
    this.prop('rw', 'historyStartAt', null);
    this.prop('rw', 'historyStopAt', null);
    this.prop('rw', 'last_active', new Time(params.last_active));
    this.prop('rw', 'last_read', new Time(params.last_read));
    this.prop('rw', 'messages', []);
    this.prop('rw', 'modes', {});
    this.prop('rw', 'name', params.name || params.dialog_id || params.connection_id || 'ERR');
    this.prop('rw', 'status', 'pending');
    this.prop('rw', 'topic', params.topic || '');
    this.prop('rw', 'unread', params.unread || 0);

    if (params.hasOwnProperty('dialog_id')) {
      this.prop('ro', 'dialog_id', params.dialog_id);
      this.prop('ro', 'title', () => [this.name, this.connection_id].join(' - '));
      this.prop('rw', 'frozen', params.frozen || '');
    }
    else {
      this.prop('ro', 'frozen', () => this._calculateFrozen());
      this.prop('ro', 'title', () => this.name);
    }

    if (params.dialog_id) {
      this.prop('persist', 'wantNotifications', false, {key: params.dialog_id +  ':wantNotifications', lazy: true});
    }

    this.socket = params.socket || getSocket('/events');
    this._addOperations();
  }

  addMessage(msg) {
    this._maybeIncreaseUnread(msg);
    this._maybeNotify(msg);
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
      if (!msg.from) [msg.internal, msg.from, msg.fromId] = [true, this.connection_id || 'Convos', 'Convos'];
      if (!msg.fromId) msg.fromId = msg.from.toLowerCase();
      if (!msg.type) msg.type = 'notice'; // TODO: Is this a good default?
      if (msg.vars) msg.message = l(msg.message, ...msg.vars);

      msg.id = 'msg_' + (++nMessages);
      msg.color = msg.fromId == 'Convos' ? 'inherit' : str2color(msg.from.toLowerCase());
      msg.ts = new Time(msg.ts);
      msg.embeds = (msg.message.match(/https?:\/\/(\S+)/g) || []).map(url => url.replace(/(\W)?$/, ''));
      msg.markdown = md(msg.message);
    }

    this.update({messages});
    return this;
  }

  is(status) {
    if (status == 'connection') return !this.dialog_id;
    if (status == 'conversation') return this.dialog_id && !this.is('notifications');
    if (status == 'frozen') return this.frozen && true;
    if (status == 'locked') return this.frozen == 'Invalid password.';
    if (status == 'notifications') return false;
    if (status == 'private') return this.is_private;
    if (status == 'search') return false;
    if (status == 'unread') return this.unread && true;
    return this.status == status;
  }

  async load(params = {}) {
    if (!this.messagesOp || this.is('loading')) return this;
    if (this._hasEndOfStream(params)) return this;

    const internalMessages = [];
    if (this._shouldClearMessages(params)) {
      internalMessages.push.apply(internalMessages, this.messages.filter(msg => msg.internal));
      this.update({messages: []});
    }

    // Load messages
    this.update({status: 'loading'});
    if (!params.limit) params.limit = params.around ? 30 : 40;
    await this.messagesOp.perform({...params, connection_id: this.connection_id, dialog_id: this.dialog_id});
    const body = this.messagesOp.res.body;
    this.addMessages(params.before ? 'unshift' : 'push', body.messages || []);
    this.addMessages('push', internalMessages);
    this.update({status: this.messagesOp.status});
    this._setEndOfStream(params, body);
    if (this.messages.length <= 10) this.update({first_time: true});

    [0, -1].forEach(index => {
      const msg = this.messages.slice(index)[0];
      const bodyKey = index ? 'history_stop' : 'history_start';
      if (msg && msg.ts.toISOString() == body[bodyKey]) this.update({[camelize(bodyKey)]: msg.ts});
    });

    return this;
  }

  findParticipant(nick) {
    return this._participants.get(this._participantId(isType(nick, 'undef') ? '' : nick));
  }

  participants(participants = []) {
    participants.forEach(p => {
      if (!p.nick) p.nick = p.name || ''; // TODO: Just use "name"?
      const id = this._participantId(p.nick);
      const existing = this._participants.get(id);

      if (existing) {
        Object.keys(p).forEach(k => { existing[k] = p[k] });
        p = existing;
      }

      // Do not delete p.mode, since it is used by wsEventSentNames()
      if (!p.modes) p.modes = {};
      this._calculateModes(userModeCharToModeName, p.mode, p.modes);
      this._participants.set(id, {name: p.nick, ...p, color: str2color(id), id, ts: new Time()});
    });

    if (participants.length) this.update({_participants: true});

    return this._participants.toArray();
  }

  send(message) {
    if (typeof message == 'string') message = {message};
    return this.socket.send({method: 'send', connection_id: this.connection_id, dialog_id: this.dialog_id || '', ...message});
  }

  async setLastRead() {
    if (!this.setLastReadOp) return;
    this.update({errors: 0, unread: 0});
    await this.setLastReadOp.perform({connection_id: this.connection_id, dialog_id: this.dialog_id});
    return this.update({last_read: new Time()});
  }

  update(params) {
    this._loadParticipants();
    return super.update(params);
  }

  wsEventRtc(params) {
    if (params.type == 'call') this.addMessage({highlight: true, message: '%1 is calling.', vars: [params.from]});
    if (params.type == 'hangup') this.addMessage({message: '%1 ended the call.', vars: [params.from]});
    this.emit('rtc', params);
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
    this.participants([{nick: params.new_nick}]);
    const message = params.type == 'me' ? 'You (%1) changed nick to %2.' : '%1 changed nick to %2.';
    this.addMessage({message, vars: [params.old_nick, params.new_nick]});
  }

  wsEventPart(params) {
    const participant = this.findParticipant(params.nick);
    if (!participant || participant.me) return;
    this._participants.delete(this._participantId(params.nick));
    this.update({_participants: true});
    this.addMessage(this._partMessage(params));
  }

  wsEventSentClear(params) {
    if (params.errors) return;
    this.update({messages: []});
    this.addMessage({message: 'History was cleared for %1.', vars: [this.name]});
  }

  wsEventSentNames(params) {
    this._updateParticipants(params);

    const msg = {message: 'Participants (%1): %2', vars: []};
    const participants = this._participants.toArray().map(p => (modeMoniker[p.mode] || p.mode || '') + p.name);
    if (participants.length > 1) {
      msg.message += ' and %3.';
      msg.vars[2] = participants.pop();
    }

    msg.vars[0] = participants.length;
    msg.vars[1] = participants.join(', ');
    this.addMessage(msg);
  }

  wsEventSentTopic(params) {
    const message = params.topic ? 'Topic for %1 is: %2': 'No topic is set for %1.';
    this.addMessage({message, vars: [this.name, params.topic]});
    this.update({topic: params.topic});
  }

  _addOperations() {
    this.prop('ro', 'messagesOp', api('/api', 'dialogMessages'));
    this.prop('ro', 'setLastReadOp', api('/api', 'setDialogLastRead'));
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

  _hasEndOfStream(opParams) {
    if (!this.messages.length) return this.is('success');
    return (opParams.before && this.historyStartAt) || (opParams.after && this.historyStopAt);
  }

  _loadParticipants() {
    if (this.participantsLoaded || !this.dialog_id || !this.messagesOp) return;
    if (this.is('frozen') || !this.messagesOp.is('success')) return;
    this.participantsLoaded = true;
    return this.is_private ? this.send('/ison') : this.send('/names').then(this._updateParticipants.bind(this));
  }

  _maybeIncreaseUnread(msg) {
    if (!msg.from || msg.yourself) return;
    if (['action', 'error', 'private'].indexOf(msg.type) == -1) return;
    this.update({unread: this.unread + 1});
  }

  _maybeNotify(msg) {
    if (!msg.from || msg.yourself) return;
    if (!msg.highlight && !this.is_private && !this.wantNotifications) return;
    if (['action', 'error', 'private'].indexOf(msg.type) == -1) return;
    if (notify.appHasFocus) return;

    const title = msg.from == this.name ? msg.from : l('%1 in %2', msg.from, this.name);
    this.lastNotification = notify.show(msg.message, {path: this.path, title});
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

  _realMessage(start) {
    const incBy = start == -1 ? -1 : 1;
    const messages = this.messages;
    let i = start == -1 ? this.messages.length - 1 : 0;

    while (messages[i]) {
      if (!messages[i].internal) return messages[i];
      i += incBy;
    }

    return null;
  }

  _setEndOfStream(params, body) {
    if (!params.before && !body.after) {
      const msg = this.messages.slice(-1)[0];
      this.update({historyStopAt: new Time(msg && msg.ts)});
    }
    if (!params.after && !body.before) {
      const msg = this.messages[0];
      this.update({historyStartAt: new Time(msg && msg.ts)});
    }
    if (body.messages && body.messages.length <= 1) {
      this.update({historyStartAt: new Time(), historyStopAt: new Time()});
    }
  }

  _shouldClearMessages(opParams) {
    // before=...
    const firstMessage = this.messages[0];
    if (!firstMessage) return false;
    if (opParams.before && opParams.before != firstMessage.ts.toISOString()) return true;

    // after=...
    const lastMessage = this.messages.slice(-1)[0];
    if (opParams.after && opParams.after != lastMessage.ts.toISOString()) return true;
    if (!opParams.after && !opParams.before && !this.historyStopAt) return true;

    // around=...
    if (opParams.around) return this.messages.includes(msg => msg.ts.toISOString() == opParams.around);

    return false;
  }

  _updateParticipants(params) {
    this._participants.clear();
    this.participants(params.participants);
    params.stopPropagation();
  }
}
