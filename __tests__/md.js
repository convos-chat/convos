import '../public/images/emojis.js';
import {md} from '../assets/js/md';

test('unchanged', () => {
  expect(md('foo')).toBe('foo');
  expect(md('Some text!')).toBe('Some text!');
});

test('blockquote', () => {
  expect(md('> Some quote')).toBe('<blockquote>Some quote</blockquote>');
});

test('emoji', () => {
  expect(countEmojis(':) :/ :( ;D &lt;3 :D :P ;) :heart:')).toBe(8);
});

test('em, strong', () => {
  expect(md('Hey *foo* **bar** ***baz***!'))
    .toBe('Hey <em>foo</em> <strong>bar</strong> <em><strong>baz</strong></em>!');
});

test('markdown link', () => {
  expect(md('some [cool chat](https://convos.chat)'))
    .toBe('some <a href="https://convos.chat" target="_blank">cool chat</a>');
  expect(md('A link to https://convos.chat'))
    .toBe('A link to <a href="https://convos.chat" target="_blank">https://convos.chat</a>');
  expect(md('A link to mailto:jhthorsen@cpan.org'))
    .toBe('A link to <a href="mailto:jhthorsen@cpan.org" target="_blank">jhthorsen@cpan.org</a>');
});

test('code', () => {
  expect(md('is this \\`not code`, or..?'))
    .toBe('is this `not code`, or..?');
  expect(md('is this `not code`, or..?'))
    .toBe('is this <code>not code</code>, or..?');
  expect(md('not a `https://link.com`'))
    .toBe('not a <code><a href="https://link.com" target="_blank">https://link.com</a></code>');
  expect(md('a regexp: `TShop\.Setup\(\s*([{](?>[^\\"{}]+|"(?>[^\\"]+|\\[\S\s])*"|\\[\S\s]|(?-1))*[}])`'))
    .toBe('a regexp: <code>TShop\.Setup\(\s*([{](?&gt;[^\\&quot;{}]+|&quot;(?&gt;[^\\&quot;]+|\\[\S\s])*&quot;|\\[\S\s]|(?-1))*[}])</code>');
  expect(md('kikuchi` changed nick to kikuchi```.'))
    .toBe('kikuchi` changed nick to kikuchi```.');
});

function countEmojis(str) {
  return md(str).match(/class="emoji"/g).length;
}
