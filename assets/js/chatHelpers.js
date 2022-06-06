import {extractErrorMessage, q, showFullscreen, tagNameIs} from '../js/util';
import {get} from 'svelte/store';
import {i18n} from '../store/I18N';
import {route} from '../store/Route';
import {videoWindow} from '../store/video';

export function awayMessage(params) {
  if (!params.nick) return ['Loading...'];

  const channels = Object.keys(params.channels || {}).sort();
  const vars = [params.nick, params.name || params.user];
  let message = '%1 (%2)';

  if (params.away) {
    message += ' is away (%3) and';
    vars.push(params.away);
  }

  if (params.idle_for && channels.length) {
    message += ' has been idle for %4s in %5.';
    vars.push(params.idle_for);
    vars.push(channels.sort().join(', '));
  }
  else if (params.idle_for && !channels.length) {
    message += ' has been idle for %4s, and is not in any channels.';
    vars.push(params.idle_for);
  }
  else if (channels.length) {
    message += ' is active in %4.';
    vars.push(channels.join(', '));
  }
  else {
    message += ' is not in any channels.';
  }

  if (!params.away) {
    message = message.replace(/%(4|5)/g, (_all, n) => '%' + (n - 1));
  }

  return [message, ...vars];
}

// Exports other functions
export function chatHelper(method, state) {
  if (method == 'onInfinityScrolled') return (...params) => onInfinityScrolled(state, ...params);
  if (method == 'onInfinityVisibility') return (...params) => onInfinityVisibility(state, ...params);
  if (method == 'onMessageClick') return (...params) => onMessageClick(state, ...params);
}

// Exported
export function conversationUrl(message) {
  const path = ['', 'chat', message.connection_id];
  if (message.conversation_id) path.push(message.conversation_id);
  return route.urlFor(path.map(encodeURIComponent).join('/') + '#' + message.ts.toISOString());
}

// Exported
export function gotoConversation(e) {
  if (e.target.closest('a')) return;
  e.preventDefault();
  route.go(e.target.closest('.message').querySelector('a').href);
}

// Available through chatHelper()
function onInfinityScrolled({conversation}, e) {
  const visibleEls = e.detail.visibleEls.filter(el => el.dataset.ts);
  if (!visibleEls.length) return;

  const go = (hash) => route.go(conversation.path + (hash.length ? '#' + hash : ''), {replace: true});
  const pos = e.detail.pos;
  if (pos == 'top') {
    const before = visibleEls[0].dataset.ts;
    if (!conversation.historyStartAt) conversation.load({before});
    go(before);
  }
  else if (pos == 'bottom') {
    const after = visibleEls.slice(-1)[0].dataset.ts;
    if (!conversation.historyStopAt) conversation.load({after});
    go(conversation.historyStopAt ? '' : after);
  }
  else {
    go(visibleEls[0].dataset.ts);
  }
}

// Available through chatHelper()
export function onInfinityVisibility({conversation, onLoadHash}, e) {
  const {infinityEl, scrollHeightChanged, scrollTo, visibleEls, visibleElsChanged} = e.detail;
  const messages = conversation.messages;
  const hasScrollbar = infinityEl.scrollHeight > infinityEl.offsetHeight;

  if (!hasScrollbar && messages.length) {
    conversation.load({before: messages.get(0).ts.toISOString()});
  }
  if (scrollHeightChanged) {
    scrollTo(route.hash ? '.message[data-ts="' + route.hash + '"]' : -1);
    renderFocusedEl(infinityEl, onLoadHash == route.hash);
  }
  if (visibleElsChanged) {
    visibleEls.forEach(el => messages.render(el.dataset.index));
  }
}

// Internal
function onMessageActionClick({conversation, fillIn, focusChatInput, popoverTarget}, e, action) {
  e.preventDefault();
  if (action[0] == 'popover') {
    popoverTarget.set(get(popoverTarget) == action[1] ? null : action[1]);
  }
  else if (action[1] == 'details') {
    const msg = conversation.messages.get(action[2]);
    msg.showDetails = !msg.showDetails;
    conversation.messages.update({messages: true});
  }
  else if (action[1] == 'close') {
    conversation.send('/close ' + (action[2] ? decodeURIComponent(action[2]) : conversation.conversation_id));
    route.go('/settings/conversation');
  }
  else if (action[1] == 'join') {
    popoverTarget.set(null);
    conversation.send('/join ' + (action[2] ? decodeURIComponent(action[2]) : conversation.conversation_id));
  }
  else if (action[1] == 'mention') {
    popoverTarget.set(null);
    fillIn(action[2], {});
    focusChatInput();
  }
  else if (action[1] == 'whois') {
    popoverTarget.set(null);
    conversation.send('/whois ' + decodeURIComponent(action[2]), (sent) => {
      const message = extractErrorMessage(sent);
      if (message) conversation.addMessages({message, sent, type: 'error'});
    });
  }
  else {
    console.warn('Unhandled onMessageActionClick', action);
  }
}

// Available through chatHelper()
function onMessageClick(curried, e) {
  const aEl = e.target.closest('a');

  // Make sure embed links are opened in a new tab/window
  if (aEl && !aEl.target && e.target.closest('.embed')) aEl.target = '_blank';

  // Proxy video links
  const videoEl = aEl && document.querySelector('[target="convos_video"][href="' + aEl.href + '"]');
  if (videoEl) return onVideoLinkClick(curried, e, videoEl);

  // Expand/collapse pastebin, except when clicking on a link
  const pasteMetaEl = e.target.closest('.le-meta');
  if (pasteMetaEl) return aEl || pasteMetaEl.parentNode.classList.toggle('is-expanded');

  // Special links with actions in #hash
  const action = aEl && aEl.href.match(/#(action|popover):(\w+):?(.*)/);
  if (action) return onMessageActionClick(curried, e, action.slice(1));

  // Show images in full screen
  if (tagNameIs(e.target, 'img')) return showFullscreen(e, e.target);
  if (aEl && aEl.classList.contains('le-thumbnail')) return showFullscreen(e, aEl.querySelector('img'));
}

// Available through chatHelper()
function onVideoLinkClick({conversation}, e, aEl) {
  // https://convos.chat/video/meet.jit.si/irc-localhost-whatever?nick=superman
  // https://meet.jit.si/irc-libera-superman-and-superwoman
  const nick = conversation.participants.me().nick;
  if (aEl.href.indexOf('/video/') != -1) {
    const url = new URL(aEl.href);
    e.preventDefault();
    videoWindow.open(route.urlFor(url.pathname.replace(/.*?\/video\//, '/video/')), {nick});
  }
  else if (aEl.closest('.le-provider-convosapp') || aEl.closest('.le-provider-jitsi')) {
    const url = new URL(aEl.href);
    e.preventDefault();
    videoWindow.open(route.urlFor('/video/' + url.hostname + url.pathname), {nick});
  }
}

// Exported
export function renderEmbed(el, embed) {
  const parentNode = embed.nodes[0] && embed.nodes[0].parentNode;
  if (parentNode && parentNode.classList) {
    const method = parentNode.classList.contains('embed') ? 'add' : 'remove';
    parentNode.classList[method]('hidden');
  }

  embed.nodes.forEach(node => el.appendChild(node));
}

// Internal
function renderFocusedEl(infinityEl, add) {
  const focusEl = add && route.hash && infinityEl.querySelector('.message[data-ts="' + route.hash + '"]');
  q(infinityEl, '.has-focus', (el) => el.classList.remove('has-focus'));
  if (focusEl) focusEl.classList.add('has-focus');
}

// Exported
export function topicOrStatus(connection, conversation) {
  if (conversation.is('not_found')) return '';
  if (connection.frozen) return connection.frozen;
  if (connection == conversation) return 'Connection messages.';
  if (conversation.info.away) return conversation.info.away;
  if (conversation.info.idle_for) return i18n.l('User has been idle for %1s.', conversation.info.idle_for);
  const str = conversation.frozen ? conversation.frozen : conversation.topic;
  return str || (conversation.is('private') ? 'Private conversation.' : 'No topic is set.');
}
