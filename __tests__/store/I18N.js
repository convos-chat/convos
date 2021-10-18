import {emojis} from '../../public/emojis/0bf11a9aff0d6da7b46f1490f86a71eb.json';
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

test('lmd()', () => {
  expect(i18n.lmd('`code` %1 *is* cool.', 42)).toBe('<code>code</code> 42 <em>is</em> cool.');

  // Entities should not be translated into "undefined"
  expect(i18n.lmd('https://commons.wikimedia.org/wiki/File:HK_WCD_WC_%E7%81%A3%E4%BB%94_Wan_Chai_%E8%BB%92%E5%B0%BC%E8%A9%A9%E9%81%93_Hennessy_Road_tram_body_ads_Tsingtao_Brewery_August_2021_SS2.jpg'))
    .toBe('<a href="https://commons.wikimedia.org/wiki/File:HK_WCD_WC_%E7%81%A3%E4%BB%94_Wan_Chai_%E8%BB%92%E5%B0%BC%E8%A9%A9%E9%81%93_Hennessy_Road_tram_body_ads_Tsingtao_Brewery_August_2021_SS2.jpg" target="_blank">https://commons.wikimedia.org/wiki/File:HK_WCD_WC_%E7%81%A3%E4%BB%94_Wan_Chai_%E8%BB%92%E5%B0%BC%E8%A9%A9%E9%81%93_Hennessy_Road_tram_body_ads_Tsingtao_Brewery_August_2021_SS2.jpg</a>');
});

test('md - not lmd', () => {
  expect(i18n.md('`code` %1 *is* cool.')).toBe('<code>code</code> %1 <em>is</em> cool.');
});

test('md - unchanged', () => {
  expect(i18n.md('foo')).toBe('foo');
  expect(i18n.md('Some text!')).toBe('Some text!');
});

test('md - blockquote', () => {
  expect(i18n.md('> Some quote')).toBe('<blockquote>Some quote</blockquote>');
});

test('md - emojis', () => {
  i18n.emojis._load(emojis);
  expect(countEmojis(':) :/ :( ;D &lt;3 :D :P ;) :heart:')).toBe(8);
  expect(i18n.md('wouldn\'t it need :// too?'))
    .toBe('wouldn&apos;t it need :// too?');
  expect(i18n.md('but :/. turns into an emoji'))
    .toMatch(/but <img.*[^>]+>. turns into an emoji/);
});

test('md - em, strong', () => {
  expect(i18n.md('Hey *foo* **bar** ***baz***!'))
    .toBe('Hey <em>foo</em> <strong>bar</strong> <em><strong>baz</strong></em>!');
});

test('md - markdown link', () => {
  expect(i18n.md('some [cool chat](https://convos.chat)'))
    .toBe('some <a href="https://convos.chat" target="_blank">cool chat</a>');
  expect(i18n.md('A link to https://convos.chat, cool ey?'))
    .toBe('A link to <a href="https://convos.chat" target="_blank">https://convos.chat</a>, cool ey?');
  expect(i18n.md('A link to mailto:jhthorsen@cpan.org!'))
    .toBe('A link to <a href="mailto:jhthorsen@cpan.org" target="_blank">jhthorsen@cpan.org</a>!');
  expect(i18n.md('https://ru.wikipedia.org/wiki/Участница:Gryllida/Черновик last symbol shows as separate outside of the URL? do you reproduce the bug?'))
    .toBe('<a href=\"https://ru.wikipedia.org/wiki/Участница:Gryllida/Черновик\" target=\"_blank\">https://ru.wikipedia.org/wiki/Участница:Gryllida/Черновик</a> last symbol shows as separate outside of the URL? do you reproduce the bug?');
});

test('md - code', () => {
  expect(i18n.md('single `a` char'))
    .toBe('single <code>a</code> char');
  expect(i18n.md('is this \\`not code`, or..?'))
    .toBe('is this `not code`, or..?');
  expect(i18n.md('is this `not code`, or..?'))
    .toBe('is this <code>not code</code>, or..?');
  expect(i18n.md('not a `https://link.com`'))
    .toBe('not a <code>https://link.com</code>');
  expect(i18n.md('a regexp: `TShop\.Setup\(\s*([{](?>[^\\"{}]+|"(?>[^\\"]+|\\[\S\s])*"|\\[\S\s]|(?-1))*[}])`'))
    .toBe('a regexp: <code>TShop\.Setup\(\s*([{](?&gt;[^\\&quot;{}]+|&quot;(?&gt;[^\\&quot;]+|\\[\S\s])*&quot;|\\[\S\s]|(?-1))*[}])</code>');
  expect(i18n.md('kikuchi` changed nick to kikuchi```.'))
    .toBe('kikuchi` changed nick to kikuchi```.');
});

test('md - nbsp', () => {
  expect(i18n.md('')).toBe('&nbsp;');
  expect(i18n.md('    ___ ___  _  ___   _____  ___')).toBe('&nbsp; &nbsp; ___ ___ &nbsp;_ &nbsp;___ &nbsp; _____ &nbsp;___');
});

test('md - channel names', () => {
  expect(i18n.md('#foo #foo-bar#not href="#anchor" #foo.bar'))
    .toBe('<a href=\"./%23foo\">#foo</a><a href=\"./%20%23foo-bar\"> #foo-bar</a>#not href=&quot;#anchor&quot;<a href=\"./%20%23foo.bar\"> #foo.bar</a>');
});

function countEmojis(str) {
  return i18n.md(str).match(/class="emoji"/g).length;
}
