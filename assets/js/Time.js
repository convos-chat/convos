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

  getHumanDate() {
    return this.getDate() + '. ' + this.getMonthAbbr();
  }

  getHM() {
    return [this.getHours(), this.getMinutes()].map(v => v < 10 ? '0' + v : v).join(':');
  }

  getMonthAbbr() {
    return MONTH_ABBR[this.getMonth()] || '';
  }

  toEpoch() {
    return this.getTime() / 1000;
  }

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
