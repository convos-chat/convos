/**
 * SortedMap extends the JavaScript "Map" class with more functionality.
 *
 * @exports SortedMap
 * @class SortedMap
 * @extends Map
 */

const sortByName = (a, b) => a.name.localeCompare(b.name);

export default class SortedMap extends Map {
  constructor(items = [], params = {}) {
    super(items);
    this.sorter = params.sorter || sortByName;
    this._sort();
  }

  /**
   * filter() is like Array.filter().
   *
   * @memberof SortedMap
   * @param {Function} cb The filtering function.
   */
  filter(cb) {
    return Array.from(this.values()).filter(cb);
  }

  /**
   * set() is like Map.set, but will also sort the values afterwards.
   *
   * @memberof SortedMap
   * @param {*} key
   * @param {*} val
   */
  set(key, val) {
    super.set.call(this, key, val);
    this._sort();
  }

  /**
   * Used to turn the SortedMap values into a plain Array object.
   *
   * @memberof SortedMap
   * @returns {Array} The values() as an Array.
   */
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
