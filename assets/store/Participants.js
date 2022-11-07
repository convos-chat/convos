import Reactive from '../js/Reactive';
import {calculateModes, is, str2color} from '../js/util';
import {userModeCharToModeName} from '../js/constants';

export default class Participants extends Reactive {
  constructor() {
    super();
    this.prop('ro', 'length', () => this._map.size);
    this.prop('ro', '_map', new Map());
  }

  clear() {
    const me = this.me();
    this._map.clear();
    this.add(me);
    return this;
  }

  delete(nick) {
    this._map.delete(this._id(nick));
    return this.update({});
  }

  get(nick) {
    return this._map.get(this._id(nick));
  }

  has(nick) {
    return this._map.has(this._id(nick));
  }

  me() {
    return Array.from(this._map.values()).filter(p => p.me)[0] || this._defaultParticipant();
  }

  nicks() {
    return Array.from(this._map.values()).map(p => p.nick);
  }

  rename(oldNick, newNick) {
    const existing = this.get(oldNick) || {};
    delete existing.id;
    existing.nick = newNick;
    this.delete(oldNick);
    return this.add(existing);
  }

  add(participant) {
    if (Array.isArray(participant)) {
      participant.forEach(p => this.add(p));
      return this;
    }

    participant.id = this._id(participant.nick);
    participant.color = str2color(participant.id);
    participant.group = str2color(participant.id);
    if (is.string(participant.mode)) {
      participant.modes = calculateModes(userModeCharToModeName, participant.mode);
      participant.group // Must be in sync with constants.js
        = participant.modes.founder       ? 7
        : participant.modes.admin         ? 6
        : participant.modes.operator      ? 5
        : participant.modes.half_operator ? 4
        : participant.modes.voice         ? 3
        : participant.modes.bot           ? 2
        : participant.modes.service_bot   ? 1
        :                         0;
    }
    else {
      participant.modes = {};
      participant.group = 0;
    }

    const existing = this._map.get(participant.id);
    if (existing) Object.keys(existing).forEach(k => participant[k] || (participant[k] = existing[k]));

    if (!participant.nick) participant.nick = participant.name;

    this._map.set(participant.id, participant);
    return this.update({length: true});
  }

  toArray() {
    return Array.from(this._map.values()).sort((a, b) => {
      return b.group - a.group || a.nick.localeCompare(b.nick);
    });
  }

  _defaultParticipant() {
    return {color: '#000000', id: '', modes: {}, nick: ''};
  }

  _id(nick) {
    return nick.toLowerCase();
  }
}
