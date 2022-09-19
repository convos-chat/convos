/**
 * Time extends Date with more functinality.
 *
 * @exports Time
 * @class Time
 */
const MONTH_ABBR = {
  '0': 'Jan',
  '1': 'Feb',
  '2': 'March',
  '3': 'Apr',
  '4': 'May',
  '5': 'Jun',
  '6': 'July',
  '7': 'Aug',
  '8': 'Sept',
  '9': 'Oct',
  '10': 'Nov',
  '11': 'Dec',
};

const STRFTIME = {
  H: '_getPaddedHours',
  M: '_getPaddedMinutes',
  S: '_getPaddedSeconds',
  b: '_getMonthAbbr',
  e: 'getDate',
  Y: 'getFullYear',
};

export const isISOTimeString = str => !!String(str || '').match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);

export default class Time extends Date {
  constructor(params) {
    if (typeof params === 'string' && !params.match(/Z$/)) params += 'Z';
    super(params || new Date());
  }

  /**
   * Used to format a strftime string. Note that this method is not compatible
   * with the full specification of strftime.
   *
   * @memberof Time
   * @param {String} format A strftime format string
   * @returns {String} Example "Sept 15"
   */
  format(format) {
    return format.replace(/%(\w)/g, (all, p) => STRFTIME[p] ? this[STRFTIME[p]]() : p);
  }

  /**
   * getHumanDate() will return the date and month.
   *
   * @memberof Time
   * @returns {String} Example "Sept 15"
   */
  getHumanDate(params = {}) {
    let str = this.format('%b %e');
    const now = new Time();
    const sameYear = this.getYear() === now.getYear();
    if (!sameYear || params.year) str += ', ' + this.getFullYear();
    return str;
  }

  setDate(param, setUTC) { return [setUTC ? super.setUTCDate(param) : super.setDate(param), this][1] }
  setFullYear(param, setUTC) { return [setUTC ? super.setUTCFullYear(param) : super.setFullYear(param), this][1] }
  setHours(param, setUTC) { return [setUTC ? super.setUTCHours(param) : super.setHours(param), this][1] }
  setMilliseconds(param, setUTC) { return [setUTC ? super.setUTCMilliseconds(param) : super.setMilliseconds(param), this][1] }
  setMinutes(param, setUTC) { return [setUTC ? super.setUTCMinutes(param) : super.setMinutes(param), this][1] }
  setMonth(param, setUTC) { return [setUTC ? super.setUTCMonth(param) : super.setMonth(param), this][1] }
  setSeconds(param, setUTC) { return [setUTC ? super.setUTCSeconds(param) : super.setSeconds(param), this][1] }
  setTime(param) { return [super.setTime(param), this][1] }
  setYear(param) { return [this.setYear(param), this][1] }

  /**
   * toEpoch() returns getItem() devided by 1000.
   *
   * @memberof Time
   * @returns {Number} Example: 1572223553.235
   */
  toEpoch() {
    return this.getTime() / 1000;
  }

  _getMonthAbbr() {
    return MONTH_ABBR[this.getMonth()] || '';
  }

  _getPaddedHours() {
    return String(this.getHours()).padStart(2, '0');
  }

  _getPaddedMinutes() {
    return String(this.getMinutes()).padStart(2, '0');
  }

  _getPaddedSeconds() {
    return String(this.getSeconds()).padStart(2, '0');
  }
}
