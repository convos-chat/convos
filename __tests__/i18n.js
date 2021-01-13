import {dictionaries, l} from '../assets/js/i18n';

test('l.lang()', () => {
  expect(l.lang()).toBe('en');

  let err;
  try { l.lang('no') } catch (e) { err = e };
  expect(err.toString()).toBe('Invalid language "no".');
});

test('l()', () => {
  expect(l('Test')).toBe('Test');
  expect(l('Test %1', 42)).toBe('Test 42');

  dictionaries.en['Test %1'] = 'Foo %1 bar!';
  expect(l('Test %1', 42)).toBe('Foo 42 bar!');

  dictionaries.no = {'See %1': 'Se %1!'};
  l.lang('no');
  expect(l('Se %1!', 42)).toBe('Se 42!');
});

test('l.md()', () => {
  expect(l.md('`code` %1 *is* cool.', 42)).toBe('<code>code</code> 42 <em>is</em> cool.');
});
