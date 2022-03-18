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
    .toBe('<a href="https://commons.wikimedia.org/wiki/File:HK_WCD_WC_%E7%81%A3%E4%BB%94_Wan_Chai_%E8%BB%92%E5%B0%BC%E8%A9%A9%E9%81%93_Hennessy_Road_tram_body_ads_Tsingtao_Brewery_August_2021_SS2.jpg" target="_blank">commons.wikimedia.org/wiki/File:HK_WCD_WC_%E7%81%A3%E4%BB%94_Wan_Chai_%E8%BB%92%E5%B0%BC%E8%A9%A9%E9%81%93_Hennessy_Road_tram_body_ads_Tsingtao_Brewery_August_2021_SS2.jpg</a>');
});

test('md - raw', () => {
  expect(i18n.raw('> [not a link](https://convos.chat) `<a href="#cool" onclick=""></a>`'))
    .toBe('&gt; [not a link](https://convos.chat) `&lt;a href=&quot;#cool&quot; onclick=&quot;&quot;&gt;&lt;/a&gt;`');
});

test('md - whitespace', () => {
  expect(i18n.md('')).toBe('&nbsp;');
  expect(i18n.md('', {})).toBe('&nbsp;');
  expect(i18n.md('')).toBe('&nbsp;');
  expect(i18n.raw(' f   b a      r ')).toBe('&nbsp;f &nbsp; b a &nbsp; &nbsp; &nbsp;r&nbsp;');
  expect(i18n.md('')).toBe('&nbsp;');
  expect(i18n.md('    ___ ___  _  ___   _____  ___'))
    .toBe('&nbsp; &nbsp; ___ ___ &nbsp;_ &nbsp;___ &nbsp; _____ &nbsp;___');
});

test('md - unchanged', () => {
  expect(i18n.md('foo')).toBe('foo');
  expect(i18n.md('Some text!')).toBe('Some text!');
});

test('md - blockquote', () => {
  expect(i18n.md('> Some quote'))
    .toBe('<blockquote>Some quote</blockquote>');
  expect(i18n.md('> escape <a href="#foo">bar</a>'))
    .toBe('<blockquote>escape &lt;a href=&quot;#foo&quot;&gt;bar&lt;/a&gt;</blockquote>');
});

test('md - code', () => {
  expect(i18n.md('> Some `code example` yeah'))
    .toBe('<blockquote>Some <code>code example</code> yeah</blockquote>');
  expect(i18n.md('Some `code with **[foo](#bar)**`'))
    .toBe('Some <code>code with **[foo](#bar)**</code>');
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

test('md - em, strong', () => {
  expect(i18n.md('> Some *em text* right'))
    .toBe('<blockquote>Some <em>em text</em> right</blockquote>');
  expect(i18n.md('Some **strong text** right'))
    .toBe('Some <strong>strong text</strong> right');
  expect(i18n.md('Some ***strong em text*** right'))
    .toBe('Some <em><strong>strong em text</strong></em> right');
  expect(i18n.md('> Some * em text* right'))
    .toBe('<blockquote>Some * em text* right</blockquote>');

  // Quotes should always be escaped - Pretect against XSS
  expect(i18n.md('Hey *foo* \'"**bar**"\' ***baz***!'))
    .toBe('Hey <em>foo</em> &apos;&quot;<strong>bar</strong>&quot;&apos; <em><strong>baz</strong></em>!');
});

test('md - colors', () => {
  expect(i18n.md('\x02bold text\x02')).toBe('<strong>bold text</strong>');
  expect(i18n.md('\x1ditalic text\x1d')).toBe('<em>italic text</em>');
  expect(i18n.md('\u00035colored text\x03')).toBe('<span class="text-5">colored text</span>');
  expect(i18n.md('\u00034,12colored text and background\u0003')).toBe('<span class="bg-12 text-4">colored text and background</span>');
  expect(i18n.md('\u000302perl5\u0003 \u000307jdoe\u0003 closed pull request \u000303#19304\u0003: Pod'))
    .toBe('<span class="text-2">perl5</span> <span class="text-7">jdoe</span> closed pull request <span class="text-3">#19304</span>: Pod');
});

test('md - emojis', () => {
  i18n.emojis._load(emojis);
  expect(countEmojis(':) :/ :( ;D &lt;3 :D :P ;) :heart:')).toBe(8);
  expect(i18n.md('wouldn\'t it need :// too?'))
    .toBe('wouldn&apos;t it need :// too?');
  expect(i18n.md('but :/. turns into an emoji'))
    .toMatch(/but <img.*[^>]+>. turns into an emoji/);
});

test('md - url', () => {
  expect(i18n.md('A link to https://convos.chat, cool ey?'))
    .toBe('A link to <a href="https://convos.chat" target="_blank">convos.chat</a>, cool ey?');
  expect(i18n.md('A link to http://convos.chat, cool ey?'))
    .toBe('A link to <a href="http://convos.chat" target="_blank">http://convos.chat</a>, cool ey?');
  expect(i18n.md('A link to mailto:jhthorsen@cpan.org!'))
    .toBe('A link to <a href="mailto:jhthorsen@cpan.org" target="_blank">jhthorsen@cpan.org</a>!');
  expect(i18n.md('https://ru.wikipedia.org/wiki/Участница:Gryllida/Черновик last symbol shows as separate outside of the URL? do you reproduce the bug?'))
    .toBe('<a href=\"https://ru.wikipedia.org/wiki/Участница:Gryllida/Черновик\" target=\"_blank\">ru.wikipedia.org/wiki/Участница:Gryllida/Черновик</a> last symbol shows as separate outside of the URL? do you reproduce the bug?');
  expect(i18n.md('[mojo] marcusramberg opened pull request #1894: Minor tweaks to Growing guide. - https://git.io/JD9ph'))
    .toBe('[mojo] marcusramberg opened pull request #1894: Minor tweaks to Growing guide. - <a href=\"https://git.io/JD9ph\" target=\"_blank\">git.io/JD9ph</a>');
  expect(i18n.md('Special chars (https://convos.chat) around'))
    .toBe('Special chars (<a href="https://convos.chat" target="_blank">convos.chat</a>) around');

  // Protect against XSS
  expect(i18n.md('https://x."//onfocus="alert(document.domain)"//autofocus="" b="'))
    .toBe('<a href="https://x.&quot;//onfocus=&quot;alert(document.domain)&quot;//autofocus=&quot;" target="_blank">x.&quot;//onfocus=&quot;alert(document.domain)&quot;//autofocus=&quot;</a>&quot; b=&quot;');
});

test('md - markdown link', () => {
  expect(i18n.md('some [cool chat](https://convos.chat)'))
    .toBe('some <a href="https://convos.chat" target="_blank">cool chat</a>');
});

test('md - channel names', () => {
  expect(i18n.md('want to join #foo-1.2 #foo-bar href="#anchor" #foo.bar'))
    .toBe('want to join <a href="./%23foo-1.2">#foo-1.2</a> <a href="./%23foo-bar">#foo-bar</a> href=&quot;#anchor&quot; <a href="./%23foo.bar">#foo.bar</a>');
});

function countEmojis(str) {
  return i18n.md(str).match(/class="emoji"/g).length;
}
