import Time from '../assets/js/Time';
import {expect, test} from 'vitest';
import {isISOTimeString} from '../assets/js/Time';

test('isISOTimeString', () => {
  expect(isISOTimeString(42)).toBe(false);
  expect(isISOTimeString(false)).toBe(false);
  expect(isISOTimeString(null)).toBe(false);
  expect(isISOTimeString('2019-10-18T06:34:49')).toBe(true);
  expect(isISOTimeString('2019-10-18T06:34:49.000Z')).toBe(true);
});

test('constructor', () => {
  const t = new Time('2020-02-24T13:31:00');
  expect(t.toEpoch()).toBe(1582551060);

  const tz = new Time('2020-02-24T13:31:00Z');
  expect(tz.toEpoch()).toBe(1582551060);
});

test('format', () => {
  const t0 = new Time('2021-02-24T13:31:00');
  expect(t0.format('%H:%M')).toBe(t0.getHours() + ':31');
  expect(t0.format('%Y %b %e %H:%M')).toBe('2021 Feb 24 ' + t0.getHours() + ':31');
});

test('getHumanDate', () => {
  const year = new Time().getFullYear();
  const t0 = new Time(year + '-02-24T13:31:00');

  expect(t0.getHumanDate()).toBe('Feb 24');

  const t1 = new Time((year - 1) + '-02-24T13:31:00');
  expect(t1.getHumanDate()).toBe('Feb 24, ' + (year - 1));
});

test('format %b', () => {
  const expected = ['Jan', 'Feb', 'March', 'Apr', 'May', 'Jun', 'July', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];

  for (let i = 1; i <= 12; i++) {
    const m = i < 10 ? '0' + i : i;
    const t0 = new Time('2009-' + m + '-24T13:31:00');
    expect(t0.format('%b')).toBe(expected.shift());
  }
});

test('logic', () => {
  const t0 = new Time('2020-02-24T13:31:00');
  const t1 = new Time('2020-02-24T13:31:12');

  expect(t1 - t0).toBe(12000);
  expect(t1 < t0).toBe(false);
  expect(t1 > t0).toBe(true);
  expect(t1 - 12000).toBe(t0.valueOf());
  expect(t1.toEpoch() - t0.toEpoch()).toBe(12);
  expect(t1 == t0).toBe(false);
});
