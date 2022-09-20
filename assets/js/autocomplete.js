import {commandOptions} from './commands';
import {escapeRegExp} from 'lodash';
import {i18n} from '../store/I18N';
import {is} from './util';

export function autocomplete(category, params) {
  return autocomplete[category] ? autocomplete[category](params) : [];
}

export function fillIn(middle, params) {
  if (middle && Object.hasOwn(middle, 'val')) middle = middle.val; // Autocomplete option

  const cursorPos = params.append ? params.value.length : params.cursorPos;
  let [before, after] = [params.value.substring(0, cursorPos), params.value.substring(cursorPos)];
  if (is.undefined(middle)) return {before, middle: '', after};

  if (params.append) {
    before = before.replace(/[ ]$/, '');
    if (before.length) middle = ' ' + middle;
  }

  if (params.padBefore) {
    before = before.replace(/[ ]$/, '');
    if (before.length) middle = ' ' + middle;
  }

  if (params.padAfter) {
    after = after.replace(/^[ ]/, '');
    middle = middle + ' ';
  }

  if (params.replace) {
    before = before.replace(/\S*\s?$/, '');
  }

  return {before, middle, after};
}

export function calculateAutocompleteOptions(str, splitValueAt, {conversation, user}) {
  let key = '';
  let afterKey = '';

  const before = str.substring(0, splitValueAt).replace(/(\S)(\S*)$/, (all, b, c) => {
    key = b;
    afterKey = c;
    return '';
  });

  const autocompleteCategory =
      key === ':' && afterKey.length ? 'emojis'
    : key === '/' && !before.length  ? 'commands'
    : key === '@' && afterKey.length ? 'nicks'
    : key === '#' || key === '&'     ? 'conversations'
    :                                 'none';

  const opts = autocomplete(autocompleteCategory, {conversation, query: key + afterKey, user});
  if (opts.length) opts.unshift({autocompleteCategory, val: key + afterKey});
  return opts;
}

autocomplete.commands = ({query}) => commandOptions({query});

autocomplete.conversations = ({conversation, query, user}) => {
  const connection = user.findConversation({connection_id: conversation.connection_id});
  const conversations = connection ? connection.conversations.toArray() : user.conversations();
  const opts = [];

  for (let i = 0; i < conversations.length; i++) {
    if (conversations[i].name.toLowerCase().indexOf(query) === -1) continue;
    opts.push({text: conversations[i].name, val: conversations[i].conversation_id});
    if (opts.length >= 20) break;
  }

  return opts;
};

autocomplete.emojis = ({query}) => {
  const emojis = i18n.emojis;
  const opts = [];
  for (let emoji of emojis.search(query.substring(1))) {
    opts.push({val: emoji.emoji, text: emojis.markup(emoji.emoji)});
    if (opts.length >= 30) break;
  }

  return opts;
};

autocomplete.nicks = ({conversation, query}) => {
  const re = new RegExp('^' + escapeRegExp(query.slice(1)), 'i');
  const opts = [];

  for (let participant of conversation.participants.toArray()) {
    if (opts.length >= 20) break;
    if (participant.nick.match(re)) opts.push({val: participant.nick});
  }

  return opts;
};
