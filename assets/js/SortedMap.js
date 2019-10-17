import {sortByName} from './util';

export default class SortedMap extends Map {
  constructor(items = [], params = {}) {
    super(items);
    this.sorter = params.sorter || sortByName;
    this._sort();
  }

  set(key, val) {
    super.set.call(this, key, val);
    this._sort();
  }

  toArray() {
    return Array.from(this.values());
  }

  _sort() {
    const entries = Array.from(this.entries());
    const sorter = this.sorter;
    this.clear();
    entries.sort((a, b) => sorter(a[1], b[1])).forEach(([key, val]) => super.set.call(this, key, val));
    return entries;
  }
}
