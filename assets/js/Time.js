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
   * @returns {String} Example "15. Sept"
   */
  getHumanDate() {
    return this.getMonthAbbr() + ' ' + this.getDate();
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

  /**
   * toHuman() generates a short version of the date and time, dependent on how
   * long it is ago. Examples:
   *
   * 1. In the future: "31. Dec 21:10"
   * 2. One day ago: "14:02"
   * 3. Earlier than one day ago, but this year: "14. Apr 15:00"
   * 4. Last year: "14. Apr 2018"
   *
   * @memberof Time
   * @returns {String} A human readable short version of the date and time.
   */
  toHuman() {
    const now = new Time();
    const s = this.toEpoch();

    const tomorrow = now.toEpoch() + ONE_DAY - (now.toEpoch() % ONE_DAY);
    if (s > tomorrow + ONE_DAY) return this.getDate() + '. ' + this.getMonthAbbr() + ' ' + this.getHM();

    const yesterday = now.toEpoch() - (now.toEpoch() % ONE_DAY);
    if (s > yesterday) return this.getHM();

    const sameYear = this.getYear() == now.getYear();
    if (sameYear) return this.getDate() + '. ' + this.getMonthAbbr() + ' ' + this.getHM();

    return this.getDate() + '. ' + this.getMonthAbbr() + ' ' + this.getFullYear();
  }
}
