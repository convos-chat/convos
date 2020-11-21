import hljs from './hljs';
import Time from './Time';
import {api} from './Api';
import {lmd} from './i18n';
import {jsonhtmlify} from 'jsonhtmlify';
import {q} from './util';

export const EMBED_CACHE = {};

export const renderMessages = ({conversation, expandUrlToMedia = false, from = 'Convos', groupBy = ['fromId'], waiting = []}) => {
  const ts = new Time();

  let prev = {};
  return conversation.messages.map((msg, i) => {
    msg = {color: 'inherit', from: 'Convos', fromId: 'Convos', type: 'notice', ts, ...msg};
    msg.canToggleDetails = msg.type == 'error' || msg.type == 'notice';
    msg.groupBy = groupBy.map(k => msg[k] || '').join(':');
    msg.index = i;
    msg.isOnline = messageIsOnline(msg, conversation);
    msg.dayChanged = messageDayChanged(msg, prev);
    msg.embeds = messageEmbeds(msg, conversation, expandUrlToMedia);
    msg.className = messageClassName(msg, prev);
    prev = msg;
    return msg;
  }).concat(renderWaitingMessages({conversation, from, waiting}));
};

async function loadDetails(url, msg) {
  const details = {...(msg.sent || msg)};

  [
    'bubbles',   'canToggleDetails',  'className',   'color',
    'command',   'connection_id',     'dayChanged',  'embeds',
    'event',     'groupBy',           'id',          'index',
    'isOnline',  'markdown',          'method',      'stopPropagation',
  ].forEach(k => delete details[k]);

  return {className: 'for-jsonhtmlify hidden', html: jsonhtmlify(details).outerHTML};
}

async function loadEmbed(url) {
  const op = await api('/api', 'embed', {url}).perform();
  const embed = op.res.body;

  if (!embed.html) embed.html = '';
  embed.className = embed.provider_name ? 'for-' + embed.provider_name.toLowerCase() : embed.html ? 'for-unknown' : 'hidden';

  const embedEl = document.createRange().createContextualFragment(embed.html).firstChild;
  q(embedEl, 'img', [['error', (e) => (e.target.style.display = 'none')]]);
  const types = (embedEl && embedEl.className || '').split(/\s+/);
  if (types.indexOf('le-paste') != -1) renderPaste(embed, embedEl);

  return embed;
}

function messageClassName(msg, prev) {
  const classes = ['message'];
  if (msg.type) classes.push('is-type-' + msg.type);
  if (msg.highlight) classes.push('is-highlighted');

  classes.push(!msg.dayChanged && msg.groupBy == prev.groupBy ? 'has-same-from' : 'has-not-same-from');
  classes.push(msg.isOnline ? 'is-present' : 'is-not-present');
  return classes.join(' ');
}

function messageDayChanged(msg, prev) {
  return prev.ts && msg.ts.getDate() != prev.ts.getDate();
}

function messageEmbeds(msg, conversation, expandUrlToMedia) {
  const embeds = msg.type != 'notice' && expandUrlToMedia ? (msg.embeds || []).map(url => (EMBED_CACHE[url] || (EMBED_CACHE[url] = loadEmbed(url)))) : [];

  if (msg.canToggleDetails) {
    const cacheKey = ['details', conversation.path, msg.ts.valueOf()].join(':');
    embeds.unshift(EMBED_CACHE[cacheKey] || (EMBED_CACHE[cacheKey] = loadDetails(cacheKey, msg)));
  }

  return embeds.filter(p => p);
}

function messageIsOnline(msg, conversation) {
  if (!conversation.connection_id) return true;
  if (msg.fromId == 'Convos') return true;
  if (msg.fromId == conversation.connection_id) return true;
  return conversation.findParticipant(msg.fromId) ? true : false;
}

function renderPaste(embed, embedEl) {
  const pre = embedEl.querySelector('pre');
  if (!pre) return;
  hljs.lineNumbersBlock(pre);
  embed.html = embedEl.outerHTML;
}

function renderWaitingMessages({conversation, from, waiting}) {
  let prev = {};

  return waiting.filter(msg => msg.method == 'send' && msg.message).map((msg, i) => {
    msg = {color: 'inherit', from, fromId: from.toLowerCase(), ...msg};
    msg.canToggleDetails = true;
    msg.dayChanged = false;
    msg.groupBy = 'fromId';
    msg.index = i;
    msg.isOnline = true;
    msg.type = msg.waitingForResponse ? 'notice' : 'error';
    msg.embeds = [];
    msg.className = messageClassName(msg, prev) + ' is-waiting';
    msg.markdown = msg.waitingForResponse ? msg.message : lmd('Could not send message "%1".', msg.message);
    prev = msg;
    return msg;
  });
}
