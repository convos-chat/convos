import Reactive from '../js/Reactive';
import SortedMap from '../js/SortedMap';
import {calculateModes, camelize, isType, str2color} from '../js/util';
import {userModeCharToModeName} from '../js/constants';

export default class Participants extends Reactive {
  constructor() {
    super();

    function sorter(a, b) {
      return b.modes.operator || false - a.modes.operator || false
          || b.modes.voice || false - a.modes.voice || false
          || a.nick.localeCompare(b.nick);
    }

    this.prop('ro', 'length', () => this._map.size);
    this.prop('ro', '_map', new SortedMap([], {sorter}));
  }

  clear() {
    this._map.clear();
  }

  delete(nick) {
    this._map.delete(this._id(nick));
  }

  get(nick) {
    return this._map.get(this._id(nick));
  }

  has(nick) {
    return this._map.has(this._id(nick));
  }

  me() {
    return Array.from(this._map.values()).filter(p => p.me)[0] || this._empty();
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

    participant.color = str2color(participant.nick);
    participant.id = this._id(participant.nick);

    if (typeof participant.mode == 'string') participant.modes = calculateModes(userModeCharToModeName, participant.mode);
    if (!participant.modes) participant.modes = {};
    if (!participant.nick) participant.nick = participant.name;

    const existing = this._map.get(participant.id);
    if (existing) Object.keys(existing).forEach(k => participant[k] || (participant[k] = existing[k]));

    this._map.set(participant.id, participant);
    return this.update({length: true});
  }

  toArray() {
    return this._map.toArray();
  }

  _empty() {
    return {color: str2color(''), id: '', modes: '', nick: ''};
  }

  _id(nick) {
    return nick.toLowerCase();
  }
}
