import {camelize, isType, modeClassNames, str2color, tagNameIs, uuidv4} from '../assets/js/util';

test('camelize', () => {
  expect(camelize('foo')).toBe('foo');
  expect(camelize('foo_bar_baz')).toBe('fooBarBaz');
});

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

test('modeClassNames', () => {
  expect(modeClassNames({})).toBe('');
  expect(modeClassNames({operator: true})).toBe('has-mode-operator');
  expect(modeClassNames({operator: true, voice: true})).toBe('has-mode-operator has-mode-voice');
  expect(modeClassNames({operator: false, voice: true})).toBe('has-mode-voice');
});

test('str2color', () => {
  expect(str2color('')).toBe('#000');
  expect(str2color('supergirl')).toBe('#b06bb2');
});

test('tagNameIs', () => {
  expect(tagNameIs(null, 'body')).toBe(false);
  expect(tagNameIs({}, 'body')).toBe(false);
  expect(tagNameIs({tagName: 'BODY'}, 'body')).toBe(true);
});

test('uuidv4', () => {
  const re = expect.stringMatching('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  const uuid = [uuidv4(), uuidv4()];
  expect(uuid[0]).toEqual(re);
  expect(uuid[1]).toEqual(re);
  expect(uuid[0]).not.toBe(uuid[1]);
});
