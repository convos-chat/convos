import {isType} from '../assets/js/util';

test('isType fallback', () => {
  expect(isType(42, 'number')).toBe(true);
  expect(isType('42', 'number')).toBe(false);
});

test('isType array', () => {
  expect(isType([42], 'array')).toBe(true);
  expect(isType('42', 'array')).toBe(false);
});

test('isType object', () => {
  expect(isType({}, 'object')).toBe(true);
  expect(isType(null, 'object')).toBe(false);
});

test('isType undef', () => {
  expect(isType(undefined, 'undef')).toBe(true);
  expect(isType(null, 'undef')).toBe(true);
  expect(isType({}, 'undef')).toBe(false);
  expect(isType(false, 'undef')).toBe(false);
  expect(isType(true, 'undef')).toBe(false);
});
