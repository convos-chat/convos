/**
 * i18n is a module with helper functions for doing translations.
 * However, there is currently no languages defined.
 *
 * @module i18n
 * @exports l
 * @exports topicOrStatus
 * @see md
 */
import {md} from './md';

let LANG = 'en';

export const dictionaries = {en: {'Test %1': 'Test %1'}};

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
  const translated = String(dictionaries[LANG][lexicon] || lexicon);
  return translated.replace(/(%?)%(\d+)/g, (a, escaped, i) => {
    return escaped == '%' ? escaped + i : vars[i - 1];
  });
}

l.lang = (val, dict) => {
  if (!val) return LANG;
  if (dict) dictionaries[val] = dict;
  if (!dictionaries[val]) throw 'Invalid language "' + val + '".';
  return (LANG = val);
};

l.md = (str, ...vars) => md(l(str, ...vars));

/**
 * topicOrStatus() will look at the Connection and Conversation objects to see what
 * string represents the state.
 *
 * @param {Connection} connection
 * @param {Conversation} conversation
 * @returns {String} Example: "Private conversation."
 */
export function topicOrStatus(connection, conversation) {
  if (conversation.is('not_found')) return '';
  if (connection.frozen) return l(connection.frozen);
  if (connection == conversation) return l('Connection messages.');
  const str = conversation.frozen ? l(conversation.frozen) : conversation.topic;
  return str || (conversation.is_private && l('Private conversation.')) || l('No topic is set.');
}
