import {md} from './md';

export const dict = {en: {}};
export let lang = 'en';

export function l(lexicon, ...vars) {
  const translated = String(dict[lexicon] && dict[lexicon][lang] || lexicon);
  return translated.replace(/%(\d+)/g, (a, i) => { return vars[i - 1] });
}

export function lmd(str, params) {
  return md(l(str));
}
