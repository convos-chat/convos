import {dict, l, lang, lmd} from '../assets/js/i18n';

test('lang()', () => {
  expect(lang()).toBe('en');

  let err;
  try { lang('no') } catch (e) { err = e };
  expect(err.toString()).toBe('Invalid language "no".');
});

test('l()', () => {
  expect(l('Test')).toBe('Test');
  expect(l('Test %1', 42)).toBe('Test 42');

  dict.en['Test %1'] = 'Foo %1 bar!';
  expect(l('Test %1', 42)).toBe('Foo 42 bar!');

  dict.no = {'See %1': 'Se %1!'};
  lang('no');
  expect(l('Se %1!', 42)).toBe('Se 42!');
});

test('lmd()', () => {
  expect(lmd('`code` %1 *is* cool.', 42)).toBe('<code>code</code> 42 <em>is</em> cool.');
});
