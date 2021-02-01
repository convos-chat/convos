import Messages from './Messages';
import Reactive from '../js/Reactive';
import SortedMap from '../js/SortedMap';
import Time from '../js/Time';
import {api} from '../js/Api';
import {camelize, isType, str2color} from '../js/util';
import {channelModeCharToModeName, modeMoniker, userModeCharToModeName} from '../js/constants';
import {i18n} from './I18N';
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

export default class Conversation extends Reactive {
  constructor(params) {
    super();

    const keyPrefix = [params.connection_id, params.conversation_id, ''].filter(v => typeof v != 'undefined').join(':');
    this.prop('persist', 'userInput', '', {key: keyPrefix + 'userInput'});

    this.prop('ro', '_participants', new SortedMap([], {sorter: sortParticipants}));
    this.prop('ro', 'color', str2color(params.conversation_id || params.connection_id || ''));
    this.prop('ro', 'connection_id', params.connection_id || '');
    this.prop('ro', 'is_private', () => this.conversation_id && !channelRe.test(this.name));
    this.prop('ro', 'messages', new Messages({}));
    this.prop('ro', 'nParticipants', () => this.participants().length);
    this.prop('ro', 'path', route.conversationPath(params));

    this.prop('rw', 'historyStartAt', null);
    this.prop('rw', 'historyStopAt', null);
    this.prop('rw', 'modes', {});
    this.prop('rw', 'name', params.name || params.conversation_id || params.connection_id || 'ERR');
    this.prop('rw', 'status', 'pending');
    this.prop('rw', 'topic', params.topic || '');
    this.prop('rw', 'unread', params.unread || 0);

    if (params.hasOwnProperty('conversation_id')) {
      this.prop('ro', 'conversation_id', params.conversation_id);
      this.prop('ro', 'title', () => [this.name, this.connection_id.replace(/^\w+-/, '')].join('@'));
      this.prop('rw', 'frozen', params.frozen || '');
    }
    else {
      this.prop('ro', 'frozen', () => this._calculateFrozen());
      this.prop('ro', 'title', () => this.name);
    }

    if (params.conversation_id) {
      this.prop('persist', 'wantNotifications', this.is_private, {key: params.conversation_id +  ':wantNotifications'});
    }

    this.socket = params.socket || getSocket('/events');
    this.messages.on('notify', (msg) => this.notify(msg));
    this._addOperations();
  }

  addMessages(messages, method) {
    if (!Array.isArray(messages)) {
      this._maybeIncreaseUnread(messages);
      this._maybeNotify(messages);
      if (!this.historyStopAt && ['action', 'private'].indexOf(messages.type) != -1) return;
      messages.fresh = true;
      messages = [messages];
    }

    this.messages[method || 'push'](messages);
    return this;
  }

  is(status) {
    if (status == 'connection') return !this.conversation_id;
    if (status == 'conversation') return this.conversation_id && !this.is('notifications');
    if (status == 'frozen') return this.frozen && true;
    if (status == 'locked') return this.frozen == 'Invalid password.';
    if (status == 'not_found') return this.frozen == 'Not found.';
    if (status == 'notifications') return false;
    if (status == 'private') return this.is_private;
    if (status == 'search') return false;
    if (status == 'unread') return this.unread && true;
    return this.status == status;
  }

  async load(params = {}) {
    if (this._skipLoad(params)) return this;

    // Load messages
    this.update({status: 'loading'});
    if (!params.limit) params.limit = params.around ? 30 : 40;
    await this.messagesOp.perform({...params, connection_id: this.connection_id, conversation_id: this.conversation_id});

    this.update({status: this.messagesOp.status});

    const body = this.messagesOp.res.body;
    const internalMessages = [];
    if (params.around || (!params.after && !params.before)) {
      internalMessages.push.apply(internalMessages, this.messages.toArray().filter(msg => msg.internal));
      this.messages.clear();
    }

    this.addMessages(body.messages || [], params.before ? 'unshift' : 'push');
    this.addMessages(internalMessages, 'push');
    this._setEndOfStream(params, body);

    return this;
  }

  notify(msg) {
    if (notify.appHasFocus) return;
    const title = msg.from == this.name ? msg.from : i18n.l('%1 in %2', msg.from, this.name);
    this.lastNotification = notify.show(msg.message, {path: this.path, title});
  }

  findParticipant(nick) {
    if (nick == this.connection_id) return {id: this.connection_id, nick: this.connection_id};
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

  send(message, cb) {
    if (typeof message == 'string') message = {message};
    return this.socket.send({method: 'send', connection_id: this.connection_id, conversation_id: this.conversation_id || '', ...message}, cb);
  }

  async markAsRead() {
    if (!this.markAsReadOp) return;
    await this.markAsReadOp.perform({connection_id: this.connection_id, conversation_id: this.conversation_id});
    return this.update({unread: 0});
  }

  update(params) {
    this._loadParticipants();
    return super.update(params);
  }

  wsEventMode(params) {
    if (params.nick) {
      this.participants([{nick: params.nick, mode: params.mode}]);
      this.addMessages({message: '%1 got mode %2 from %3.', vars: [params.nick, params.mode, params.from]});
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
    this.addMessages({message, vars: [params.old_nick, params.new_nick]});
  }

  wsEventPart(params) {
    const participant = this.findParticipant(params.nick);
    if (!participant || participant.me) return;
    this._participants.delete(this._participantId(params.nick));
    this.update({_participants: true});
    if (!params.silent) {
      this.addMessages(this._partMessage(params));
    }
  }

  wsEventSentClear(params) {
    if (params.errors) return;
    this.messages.clear();
    this.addMessages({message: 'History was cleared for %1.', vars: [this.name]});
  }

  wsEventSentNames(params) {
    this._updateParticipants(params);

    const msg = {...params, message: 'Participants (%1): %2', vars: []};
    const participants = this._participants.toArray().map(p => (modeMoniker[p.mode] || p.mode || '') + p.name);
    if (participants.length > 1) {
      msg.message += ' and %3.';
      msg.vars[2] = participants.pop();
    }

    msg.vars[0] = participants.length;
    msg.vars[1] = participants.join(', ');
    this.addMessages(msg);
  }

  wsEventSentTopic(params) {
    const message = params.topic ? 'Topic for %1 is: %2': 'No topic is set for %1.';
    this.addMessages({message, vars: [this.name, params.topic]});
    this.update({topic: params.topic});
  }

  _addOperations() {
    this.prop('ro', 'messagesOp', api('/api', 'conversationMessages'));
    this.prop('ro', 'markAsReadOp', api('/api', 'markConversationAsRead'));
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
    if (this.participantsLoaded || !this.conversation_id || !this.messagesOp) return;
    if (this.is('frozen') || !this.messagesOp.is('success')) return;
    this.participantsLoaded = true;
    return this.is_private ? this.send('/whois ' + this.conversation_id) : this.send('/names', this._updateParticipants.bind(this));
  }

  _maybeIncreaseUnread(msg) {
    if (!msg.from || msg.yourself) return this;
    if (['action', 'error', 'private'].indexOf(msg.type) == -1) return this;
    this.update({unread: this.unread + 1});
  }

  _maybeNotify(msg) {
    if (!msg.from || msg.yourself) return;
    if (['action', 'error', 'private'].indexOf(msg.type) == -1) return;
    if (!msg.highlight && !this.wantNotifications) return;
    this.notify(msg);
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

  _setEndOfStream(params, body) {
    if (!params.before && !body.after) {
      const msg = body.messages.slice(-1)[0];
      this.update({historyStopAt: new Time(msg && msg.ts)});
    }
    if (!params.after && !body.before) {
      const msg = body.messages[0];
      this.update({historyStartAt: new Time(msg && msg.ts)});
    }

    if (body.after) this.update({historyStopAt: null});
    if (body.before) this.update({historyStartAt: null});
    if (body.messages && body.messages.length <= 1) this.update({historyStartAt: new Time(), historyStopAt: new Time()});
  }

  _skipLoad(opParams) {
    if (!this.messagesOp || this.is('loading')) return true;
    if (!this.messages.length) return this.is('success');
    if (opParams.around) return !!this.messages.toArray().find(msg => msg.ts.toISOString() == opParams.around);
    if (opParams.before && this.historyStartAt) return true;
    if (opParams.after && this.historyStopAt) return true;
    return false;
  }

  _updateParticipants(params) {
    this._participants.clear();
    this.participants(params.participants);
    params.stopPropagation();
  }
}
