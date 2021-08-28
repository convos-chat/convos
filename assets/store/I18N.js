import Emojis from '../js/Emojis';
import Reactive from '../js/Reactive';
import {api} from '../js/Api';
import {derived} from 'svelte/store';
import {route} from '../store/Route';

const XML_ESCAPE = {'&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&apos;', '"': '&quot;'};

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
    this._state = {};
    str = this._xmlEscape(str);
    str = this._nbsp(str);
    if (!opt.raw) str = this._mdLink(str);
    if (!opt.raw) str = this._plainUrlToLink(str);
    if (!opt.raw) str = this._extendedFormatting(str);
    if (!opt.raw) str = this._mdCode(str);
    if (!opt.raw) str = this._mdEmStrong(str);
    if (!opt.raw) str = this.emojis.markup(str);
    if (!opt.raw) str = this._mdBlockQuote(str);
    return str;
  }

  // https://modern.ircdocs.horse/formatting.html
  _extendedFormatting(str) {
    const zeroTo99 = '0[0-9]|[1-9][0-9]';
    const colorRe = new RegExp('\x03(' + zeroTo99 + ')(?:,(' + zeroTo99 + '))?([^\x03]*)', 'g');

    return str.replace(colorRe, (all, fg, bg, text) => text).replace(/[\x02\x03\x1d\x1f\x1e\x11\x16\x0f]/g, '');
  }

  _mdBlockQuote(str) {
    return str.replace(/^&gt;\s(.*)/, (all, quote) => '<blockquote>' + quote + '</blockquote>');
  }

  _mdCode(str) {
    return str.replace(/(\\?)`([^` ][^`]*)`/g, (all, esc, text) => {
      return esc ? all.replace(/^\\/, '') : '<code>' + text + '</code>';
    });
  }

  _mdEmStrong(str) {
    return str.replace(/(^|\s)(\\?)(\*+)(\w[^<]*?)\3/g, (all, b, esc, md, text) => {
      if (md.length == 1) return esc ? all.replace(/^\\/, '') : b + '<em>' + text + '</em>';
      if (md.length == 2) return esc ? all.replace(/^\\/, '') : b + '<strong>' + text + '</strong>';
      if (md.length == 3) return esc ? all.replace(/^\\/, '') : b + '<em><strong>' + text + '</strong></em>';
      return all;
    });
  }

  _mdLink(str) {
    return str.replace(/\[([a-zA-Z][^\]]+)\]\(([^)]+)\)/g, (all, text, href) => {
      const scheme = href.match(/^\s*(\w+):/) || ['', ''];
      if (scheme[1] && ['http', 'https', 'mailto'].indexOf(scheme[1]) == -1) return all; // Avoid XSS links
      this._state.md = true;
      const first = href.substring(0, 1);
      const target = ['/', '#'].indexOf(first) != -1 ? '' : ' target="_blank"';
      return '<a href="' + route.urlFor(href) + '"' + target + '>' + text + '</a>';
    });
  }

  _nbsp(str) {
    return !str.length ? '&nbsp;' : str.replace(/^\s/, '&nbsp;').replace(/\s{2}/g, ' &nbsp;');
  }

  _plainUrlToLink(str) {
    if (this._state.md) return str;

    return str.replace(/\b[a-z]{2,5}:\/\S+/g, (url) => {
      const parts = url.match(/^(.*?)(&\w+;|\W)?$/);
      return '<a href="' + parts[1] + '" target="_blank">' + parts[1] + '</a>' + (parts[2] || '');
    }).replace(/mailto:(\S+)/, (all, email) => {
      if (all.indexOf('">') != -1) return all;
      return '<a href="' + all + '" target="_blank">' + email + '</a>';
    });
  }

  _xmlEscape(str) {
    return str.replace(/[&<>"']/g, (m) => XML_ESCAPE[m]);
  }
}

export const i18n = new I18N();
export const l = derived(i18n, ($i18n) => (...params) => $i18n.l(...params));
export const lmd = derived(i18n, ($i18n) => (...params) => $i18n.lmd(...params));
