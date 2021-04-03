import {is} from '../../assets/js/util';

test('array', () => {
  expect(is.array([42])).toBe(true);
  expect(is.array('42')).toBe(false);
});

test('defined', () => {
  expect(is.defined(undefined)).toBe(false);
  expect(is.defined(null)).toBe(false);
  expect(is.defined({})).toBe(true);
  expect(is.defined(false)).toBe(true);
  expect(is.defined(true)).toBe(true);
});

test('function', () => {
  expect(is.function(() => {})).toBe(true);
  expect(is.function(null)).toBe(false);
  expect(is.function({})).toBe(false);
});

test('number', () => {
  expect(is.number(42)).toBe(true);
  expect(is.number('42')).toBe(false);
  expect(is.number([])).toBe(false);
  expect(is.number(null)).toBe(false);
});

test('object', () => {
  expect(is.object({})).toBe(true);
  expect(is.object(null)).toBe(false);
});

test('string', () => {
  expect(is.string('42')).toBe(true);
  expect(is.string(42)).toBe(false);
  expect(is.string([])).toBe(false);
  expect(is.string(null)).toBe(false);
});

test('stringable', () => {
  expect(is.stringable('42')).toBe(true);
  expect(is.stringable(42)).toBe(true);
  expect(is.stringable([])).toBe(false);
  expect(is.stringable(null)).toBe(false);
});

test('undefined', () => {
  expect(is.undefined(undefined)).toBe(true);
  expect(is.undefined(null)).toBe(true);
  expect(is.undefined({})).toBe(false);
  expect(is.undefined(false)).toBe(false);
  expect(is.undefined(true)).toBe(false);
});
