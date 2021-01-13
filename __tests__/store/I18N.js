import {i18n} from '../../assets/store/I18N';

test('l()', () => {
  expect(i18n.l('Test')).toBe('Test');
  expect(i18n.l('Test %1', 42)).toBe('Test 42');

  i18n.update({lang: 'en'});
  i18n.dictionaries.en = {'Test %1': 'Foo %1 bar!'};
  expect(i18n.l('Test %1', 42)).toBe('Foo 42 bar!');

  i18n.dictionaries.no = {'See %1': 'Se %1!'};
  i18n.update({lang: 'no'});
  expect(i18n.l('Se %1!', 42)).toBe('Se 42!');
});

test('md()', () => {
  expect(i18n.md('`code` %1 *is* cool.', 42)).toBe('<code>code</code> 42 <em>is</em> cool.');
});
