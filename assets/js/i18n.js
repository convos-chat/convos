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

export function topicOrStatus(connection, dialog) {
  if (connection.frozen) return l(connection.frozen);
  if (connection == dialog) return 'Connection messages.';
  const str = dialog.frozen ? l(dialog.frozen) : dialog.topic;
  return str || (dialog.is_private && l('Private conversation.')) || l('No topic is set.');
}
