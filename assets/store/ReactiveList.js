import Reactive from '../js/Reactive';
import {sortByName} from '../js/util';

export default class ReactiveList extends Reactive {
  constructor(items = []) {
    super();
    this._readOnlyAttr('length', () => this.items.length);
    this._updateableAttr('items', []);
  }

  add(item) {
    return this.update({items: this.items.concat(item)});
  }

  all() {
    return this.items;
  }

  clear() {
    return this.update({items: []});
  }

  find(cb) {
    return this.items.filter(cb)[0];
  }

  filter(cb) {
    return this.items.filter(cb);
  }

  map(cb) {
    return this.items.map(cb);
  }

  remove(cb) {
    return this.update({items: this.items.filter(cb)});
  }

  sort(cb = sortByName) {
    return this.update({items: this.items.sort(cb)});
  }
}
