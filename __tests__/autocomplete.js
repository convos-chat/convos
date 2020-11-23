import {fillIn} from '../assets/js/autocomplete';

test('fillIn basics', () => {
  const params = {cursorPos: 0, value: ''};

  expect(concat(fillIn('', params))).toBe('||');
  expect(concat(fillIn(undefined, params))).toBe('||');
  expect(concat(fillIn({val: ''}, params))).toBe('||');
  expect(concat(fillIn('bar', params))).toBe('|bar|');
});

test('fillIn append', () => {
  const params = {append: true, cursorPos: 1, value: 'foo'};

  expect(concat(fillIn('bar', params))).toBe('foo| bar|');

  params.value = 'foo ';
  expect(concat(fillIn('bar', params))).toBe('foo| bar|');

  params.value = '';
  expect(concat(fillIn('bar', params))).toBe('|bar|');
});

test('fillIn cursorPos', () => {
  const params = {cursorPos: 0, value: 'foo'};

  expect(concat(fillIn('bar', params))).toBe('|bar|foo');

  params.cursorPos = 2;
  expect(concat(fillIn('bar', params))).toBe('fo|bar|o');

  params.cursorPos = 3;
  expect(concat(fillIn('bar', params))).toBe('foo|bar|');

  params.cursorPos = 10;
  expect(concat(fillIn('bar', params))).toBe('foo|bar|');
});

test('fillIn padBefore', () => {
  const params = {padBefore: true, cursorPos: 0, value: 'foo'};

  expect(concat(fillIn('bar', params))).toBe('|bar|foo');
  expect(concat(fillIn(' bar', params))).toBe('| bar|foo');

  params.cursorPos = 3;
  params.value = 'foo ';
  expect(concat(fillIn('bar', params))).toBe('foo| bar| ');

  params.cursorPos = 4;
  params.value = 'foo ';
  expect(concat(fillIn('bar', params))).toBe('foo| bar|');
});

test('fillIn padAfter', () => {
  const params = {padAfter: true, cursorPos: 0, value: 'foo'};

  expect(concat(fillIn('bar', params))).toBe('|bar |foo');
  expect(concat(fillIn('bar ', params))).toBe('|bar  |foo');

  params.cursorPos = 4;
  params.value = 'foo baz';
  expect(concat(fillIn('bar', params))).toBe('foo |bar |baz');

  params.cursorPos = 3;
  params.value = 'foo baz';
  expect(concat(fillIn('bar', params))).toBe('foo|bar |baz');

  params.cursorPos = 3;
  params.value = 'foo';
  expect(concat(fillIn('bar', params))).toBe('foo|bar |');
});

test('fillIn padBefore + padAfter', () => {
  const params = {padBefore: true, padAfter: true, cursorPos: 0, value: 'foo'};

  expect(concat(fillIn('bar', params))).toBe('|bar |foo');

  params.cursorPos = 1;
  expect(concat(fillIn('bar', params))).toBe('f| bar |oo');

  params.cursorPos = 3;
  expect(concat(fillIn('bar', params))).toBe('foo| bar |');
});

test('fillIn replace', () => {
  const params = {cursorPos: 0, replace: true, value: 'foo'};

  expect(concat(fillIn('bar', params))).toBe('|bar|foo');

  params.cursorPos = 1;
  expect(concat(fillIn('bar', params))).toBe('|bar|oo');

  params.cursorPos = 3;
  expect(concat(fillIn('bar', params))).toBe('|bar|');

  params.cursorPos = 4;
  params.value = 'foo ';
  expect(concat(fillIn('bar', params))).toBe('|bar|');

  params.padAfter = true;
  expect(concat(fillIn('bar', params))).toBe('|bar |');

  params.value = 'foo baz';
  params.cursorPos = 4;
  expect(concat(fillIn('bar', params))).toBe('|bar |baz');
});

function concat({before, middle, after}) {
  return before + '|' + middle + '|' + after;
}
