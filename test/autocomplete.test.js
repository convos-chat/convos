import Participants from '../assets/store/Participants';
import {calculateAutocompleteOptions, fillIn} from '../assets/js/autocomplete';
import {emojis} from '../public/emojis/0bf11a9aff0d6da7b46f1490f86a71eb.json';
import {expect, test} from 'vitest';
import {i18n} from '../assets/store/I18N';

test('calculateAutocompleteOptions', () => {
  i18n.emojis._load(emojis);
  const params = {conversation: {participants: new Participants()}};
  params.conversation.participants.add({nick: 'superman'});
  expect(calculateAutocompleteOptions('', 0, params).length).toBe(0);

  // Commands
  expect(calculateAutocompleteOptions('/', 0, params).length).toBe(0);
  expect(calculateAutocompleteOptions('/', 1, params).length > 15).toBe(true);
  expect(calculateAutocompleteOptions('/nic fury', 4, params).length).toBe(2);
  expect(calculateAutocompleteOptions('foo /nic', 4, params).length).toBe(0);

  // Conversations
  // TODO: expect(calculateAutocompleteOptions('foo #con channel', 4, params).length).toBe(2);

  // Emoji
  expect(calculateAutocompleteOptions('foo :nor emoji', 8, params).length).toBe(6);
  expect(calculateAutocompleteOptions('foo :norw emoji', 9, params).length).toBe(2);
  expect(calculateAutocompleteOptions('foo :xyz', 8, params).length).toBe(0);

  // Nicks
  expect(calculateAutocompleteOptions('foo @su cool beans', 7, params).length).toBe(2);
  expect(calculateAutocompleteOptions('foo @sx', 7, params).length).toBe(0);
});

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
