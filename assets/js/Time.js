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

const ONE_DAY = 60 * 60 * 24;

export default class Time extends Date {
  constructor(params) {
    if (typeof params == 'string' && !params.match(/Z$/)) params += 'Z';
    super(params || new Date());
  }

  /**
   * getHumanDate() will return the date and month.
   *
   * @memberof Time
   * @returns {String} Example "Sept 15"
   */
  getHumanDate() {
    let str = this.getMonthAbbr() + ' ' + this.getDate();
    const now = new Time();
    const sameYear = this.getYear() == now.getYear();
    if (!sameYear) str += ', ' + this.getFullYear();
    return str;
  }

  /**
   * getHM() will return padded hours and minutes
   *
   * @memberof Time
   * @returns {String} Example: "09:05"
   */
  getHM() {
    return [this.getHours(), this.getMinutes()].map(v => v < 10 ? '0' + v : v).join(':');
  }

  /**
   * Used to turn getMonth() into a named month.
   *
   * @memberof Time
   * @returns {String} Jan, Feb, March, Apr, May, Jun, July, Aug, Sept, Oct, Nov or Dec.
   */
  getMonthAbbr() {
    return MONTH_ABBR[this.getMonth()] || '';
  }

  /**
   * toEpoch() returns getItem() devided by 1000.
   *
   * @memberof Time
   * @returns {Number} Example: 1572223553.235
   */
  toEpoch() {
    return this.getTime() / 1000;
  }
}
