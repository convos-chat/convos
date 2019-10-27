/**
 * i18n is a module with helper functions for doing translations.
 * However, there is currently no languages defined.
 *
 * @module i18n
 * @exports l
 * @exports lmd
 * @exports topicOrStatus
 * @see md
 */
import {md} from './md';

export const dict = {en: {}};
export let lang = 'en';

/**
 * l() is used to translate strings. The strings can contain "%1", "%2", ...
 * which will be replaced by the additional variables.
 *
 * @example
 * const translated = l('Batman is from %1.', 'Gotham');
 *
 * @param {String} lexicon A string that you want to translate.
 * @param  {...String} vars A list of variables to put into the translated string.
 */
export function l(lexicon, ...vars) {
  const translated = String(dict[lexicon] && dict[lexicon][lang] || lexicon);
  return translated.replace(/%(\d+)/g, (a, i) => { return vars[i - 1] });
}

/**
 * lmd() is a combination of l() and md(), meaning the result might be a string
 * containing HTML tags.
 *
 * @param {*} str A string that you want to translate.
 * @param {...String} vars A list of variables to put into the translated string.
 */
export function lmd(str, ...vars) {
  return md(l(str, ...vars));
}

/**
 * topicOrStatus() will look at the Connection and Dialog objects to see what
 * string represents the state.
 *
 * @param {Connection} connection
 * @param {Dialog} dialog
 * @returns {String} Example: "Private conversation."
 */
export function topicOrStatus(connection, dialog) {
  if (connection.frozen) return l(connection.frozen);
  if (connection == dialog) return 'Connection messages.';
  const str = dialog.frozen ? l(dialog.frozen) : dialog.topic;
  return str || (dialog.is_private && l('Private conversation.')) || l('No topic is set.');
}