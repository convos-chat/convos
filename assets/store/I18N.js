import Emojis from '../js/Emojis';
import Reactive from '../js/Reactive';
import {api} from '../js/Api';
import {derived} from 'svelte/store';

const ESCAPE = {'&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&apos;', '"': '&quot;'};
const escape = (str, re = /[&<>'"]/g) => str.replace(re, (m) => ESCAPE[m]);
const nbsp = (str) => str.replace(/\s$/, '&nbsp;').replace(/^\s/, '&nbsp;').replace(/\s{2}/g, ' &nbsp;');
const tagPair = (tags) => [tags.map(n => `<${n}>`).join(''), tags.reverse().map(n => `</${n}>`).join('')];

const COLORS = {
   '0': 'white',
   '1': 'black',
   '2': 'blue',
   '3': 'green',
   '4': 'red',
   '5': 'brown',
   '6': 'magenta',
   '7': 'orange',
   '8': 'yellow',
   '9': 'lightgreen',
  '10': 'cyan',
  '11': 'lightcyan',
  '12': 'lightblue',
  '13': 'pink',
  '14': 'grey',
  '15': 'lightgrey',
};

export default class I18N extends Reactive {
  constructor() {
    super();

    this.prop('cookie', 'lang', '');
    this.prop('ro', 'dictionaries', {});
    this.prop('ro', 'emojis', new Emojis());
    this.prop('ro', 'languages', () => this._languages);
    this.prop('ro', 'languageOptions', () => this._languageOptions);

    this._languages = [];
    this._languageOptions = [];
    this._rules = this._makeRules();
  }

  /**
   * Will take a lexicon and string variables and return a human readable
   * string. Falls back on returning the input lexicon if no translation
   * is provided.
   *
   * @param {String} lexicon.
   * @param {...String} A list (not array) of lexicon variables.
   * @return {String} A translated string.
   */
  l(lexicon, ...vars) {
    const dictionary = this.dictionaries[this.lang] || {};
    const translated = String(dictionary[lexicon] || lexicon);
    return translated.replace(/%(\d)(\D|$)/g, (all, i, s) => {
      return typeof vars[i - 1] == 'undefined' ? all : (vars[i - 1] + s);
    });
  }

  /**
   * Load a dictionary.
   *
   * @param {String} lang Language such as "en", "es", "it", "no", ...
   * @return {Promise} The promise will be fulfilled when the dictionary is fetched and parsed.
   */
  async load(lang) {
    if (!lang) lang = this.lang || document.documentElement.getAttribute('lang');
    if (this.dictionaries[lang]) return this.update({lang});
    const op = await api('/api', 'getDictionary', {lang}).perform();
    this.dictionaries[lang] = op.res.body.dictionary;
    this._languages = op.res.body.available_languages || {};
    this._languageOptions = Object.keys(this._languages).sort().map(id => [id, this._languages[id].language_team.replace(/\s*<.*/, '')]);
    return this.update({lang});
  }

  /**
   * Combination of l() and md().
   *
   * @param {String} lexicon.
   * @param {...String} A list (not array) of lexicon variables.
   * @return {String} A translated string which might contain HTML.
   */
  lmd(lexicon, ...vars) {
    return this.md(this.l(lexicon, ...vars));
  }

  /**
   * Combination of l() and md(), but will only render some parts.
   *
   * @param {String} lexicon.
   * @param {...String} A list (not array) of lexicon variables.
   * @return {String} A translated string which might contain HTML.
   */
  lmdRaw(lexicon, ...vars) {
    return this.md(this.l(lexicon, ...vars), {raw: true});
  }

  /**
   * md() can convert a (subset) of markdown rules into a HTML string.
   *
   * @example
   * // Hey <em>foo</em> <strong>bar</strong> <em><strong>baz</strong></em> <em><strong>baz</strong></em>
   * i18n.md("Hey *foo* **bar** ***baz***!");
   *
   * // A <a href="https://convos.chat">link</a>
   * i18n.md("A [link](https://convos.chat)");
   *
   * // A link to <a href="https://convos.chat" target="_blank">convos.chat</a>
   * i18n.md('A link to https://convos.chat');
   *
   * // A link to <a href="mailto:jhthorsen@cpan.org" target="_blank">jhthorsen@cpan.org</a>
   * i18n.md('A link to mailto:jhthorsen@cpan.org');
   *
   * // Example <code>snippet</code>
   * i18n.md("Example `snippet`");
   *
   * // <img class="emoji" draggable="false" alt="🙂" src="..."> ...
   * i18n.md(':) :/ :( ;D &lt;3 :D :P ;) :heart:');
   *
   * @param {String} str A markdown formatter string.
   * @param {Object} opt Options for rendering, such as "raw"
   * @return {String} A string that might contain HTML tags.
   */
  md(str, opt = {}) {
    return !str.length ? '&nbsp;'
         : opt.raw ? nbsp(escape(str))
         : this.emojis.markup(nbsp(this._tagToHTML(this._makeTag(str))));
  }

  _makeRules() {
    const rules = [];

    rules.push({tag: tagPair(['code']), re: /`(?=[^`\s])/, rules: [], handler: '_mdTag'});
    rules.push({tag: tagPair(['em', 'strong']), re: /\*\*\*(?=\S)/, rules, handler: '_mdTag'});
    rules.push({tag: tagPair(['strong']), re: /\*\*(?=\S)/, rules, handler: '_mdTag'});
    rules.push({tag: tagPair(['em']), re: /\*(?=\S)/, rules, handler: '_mdTag'});
    rules.push({tag: tagPair(['span']), re: /\x03\d{1,2}(?:,\d{1,2})?/, rules, handler: '_mdIrcColorFormatting'});
    rules.push({tag: tagPair(['span']), re: /[\x02\x1d\x1e\x1f\x11]/, rules, handler: '_mdIrcTextFormatting'});
    rules.push({tag: tagPair(['a']), re: /\[([a-zA-Z][^\]]+)\]\(([^)]+)\)/, rules: [], handler: '_mdLink'});
    rules.push({tag: tagPair(['a']), re: /\b(https?|mailto):\S+/, rules: [], handler: '_mdURL'});
    rules.push({tag: tagPair(['a']), re: /(?<=\s|^)#[a-zA-Z][\w.-]+(?=\W|$)/, rules: [], handler: '_mdChannelname'});

    return rules;
  }

  _makeTag(str, rules = this._rules, depth = 0) {
    // blockquote
    if (depth == 0 && str.indexOf('> ') == 0) {
      return [tagPair(['blockquote']), {}, [this._makeTag(str.replace(/^>\s/, ''), rules, depth + 1)]];
    }

    const children = [];
    for (const rule of rules) {
      const match = str.match(rule.re);
      if (!match) continue;

      const tag = {
        attrs: {},
        after: str.substring(match.index + match[0].length),
        before: str.substring(0, match.index),
        captured: match[0],
        index: match.index,
        match,
        tag: rule.tag,
      };

      this[rule.handler](tag);
      if (typeof tag.content !== 'string') {
        str = tag.before + tag.captured + tag.after;
        continue;
      }

      if (tag.before.length) children.push(this._makeTag(tag.before, rules, depth + 1));
      children.push([tag.tag, tag.attrs, [this._makeTag(tag.content, rule.rules, depth + 1)]]);
      if (tag.after.length) children.push(this._makeTag(tag.after, rules, depth + 1));
      break;
    }

    return [null, {}, children.length ? children : [escape(str)]];
  }

  _mdChannelname(tag) {
    tag.content = tag.captured;
    tag.attrs.href = './' + encodeURIComponent(tag.captured);
  }

  // https://modern.ircdocs.horse/formatting.html
  _mdIrcColorFormatting(tag) {
    const end = tag.after.indexOf('\x03');
    if (end == -1) return;
    tag.content = tag.after.substring(0, end);
    tag.after = tag.after.substring(end + tag.captured.length);

    const style = [];
    const color = tag.captured.replace(/\x030?(\d{1,2}).*/, '$1');
    if (COLORS[color]) style.push('color:' + COLORS[color]);
    const background = tag.captured.replace(/.*,(\d{1,2}).*/, '$1');
    if (COLORS[background]) style.push('background-color:' + COLORS[background]);
    if (style.length) tag.attrs.style = style.join(';');
  }

  // https://modern.ircdocs.horse/formatting.html
  _mdIrcTextFormatting(tag) {
    const end = tag.after.indexOf(tag.captured);
    if (end == -1) return;

    tag.content = tag.after.substring(0, end);
    tag.after = tag.after.substring(end + tag.captured.length);
    tag.tag = tag.captured == '\x02' ? tagPair(['strong'])
              : tag.captured == '\x1d' ? tagPair(['em'])
              : tag.captured == '\x1f' ? tagPair(['u'])
              : tag.captured == '\x11' ? tagPair(['code'])
              : tagPair(['span']);
  }

  _mdLink(tag) {
    tag.content = tag.match[1];
    tag.attrs.href = escape(tag.match[2]);
    if (tag.match[2].match(/^\w+:/)) tag.attrs.target = '_blank';
  }

  _mdTag(tag) {
    // Check if the matched character was escaped
    if (tag.before.match(/\\$/)) {
      tag.before = tag.before.replace(/\\$/, '');
      return;
    }

    const end = tag.after.indexOf(tag.captured);
    if (end == -1) return;
    tag.content = tag.after.substring(0, end);
    tag.after = tag.after.substring(end + tag.captured.length);
  }

  _mdURL(tag) {
    tag.captured = tag.captured.replace(/[,.:;!"\']$/, (after) => {
      tag.after = after[0] + tag.after;
      return '';
    });

    tag.content = tag.captured.replace(/^(https|mailto):(\/\/)?/, '');
    tag.attrs.href = escape(tag.captured);
    tag.attrs.target = '_blank';
  }

  _tagToHTML(tag) {
    if (typeof tag === 'string') return tag;

    const inner = typeof tag[2] === 'string' ? escape(tag[2]) : tag[2].map(n => this._tagToHTML(n)).join('');
    if (!tag[0]) return inner;

    const attrs = Object.keys(tag[1]).sort().map(k => `${k}="${tag[1][k]}"`).join(' ');
    const startTag = !attrs ? tag[0][0] : tag[0][0].replace(/>/, ' ' + attrs + '>');
    return startTag + inner + tag[0][1];
  }
}

export const i18n = new I18N();
export const l = derived(i18n, ($i18n) => (...params) => $i18n.l(...params));
export const lmd = derived(i18n, ($i18n) => (...params) => $i18n.lmd(...params));
