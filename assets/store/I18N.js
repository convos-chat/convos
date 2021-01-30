import Reactive from '../js/Reactive';
import {api} from '../js/Api';
import {derived} from 'svelte/store';
import {md} from '../js/md';

export default class I18N extends Reactive {
  constructor() {
    super();

    this.prop('cookie', 'lang', '');
    this.prop('ro', 'dictionaries', {});
    this.prop('ro', 'languages', () => this._languages);
    this.prop('ro', 'languageOptions', () => this._languageOptions);

    this._languages = [];
    this._languageOptions = [];
  }

  l(lexicon, ...vars) {
    const dictionary = this.dictionaries[this.lang] || {};
    const translated = String(dictionary[lexicon] || lexicon);
    return translated.replace(/(%?)%(\d+)/g, (a, escaped, i) => {
      return escaped == '%' ? escaped + i : vars[i - 1];
    });
  }

  async load(lang) {
    if (!lang) lang = this.lang || document.documentElement.getAttribute('lang');
    const op = await api('/api', 'getDictionary', {lang}).perform();
    this.dictionaries[lang] = op.res.body.dictionary;
    this._languages = op.res.body.available_languages || {};
    this._languageOptions = Object.keys(this._languages).sort().map(id => [id, this._languages[id].language_team.replace(/\s*<.*/, '')]);
    return this.update({lang});
  }

  md(lexicon, ...vars) {
    return md(this.l(lexicon, ...vars));
  }
}

export const i18n = new I18N();
export const l = derived(i18n, ($i18n) => (...params) => $i18n.l(...params));
export const lmd = derived(i18n, ($i18n) => (...params) => $i18n.md(...params));
