import Time from '../js/Time';
import {get, writable} from 'svelte/store';
import {q, showFullscreen, tagNameIs} from '../js/util';
import {route} from '../store/Route';

export const videoWindow = writable(null);
videoWindow.close = function() {
  const w = get(this);
  return w ? [true, w.close(), this.set(null)][0] : false;
};

videoWindow.open = function(url) {
  const w = window.open(url.toString(), 'convos_video');
  ['beforeunload', 'close'].forEach(name => w.addEventListener(name, () => this.set(null)));
  this.set(w);
};

// Exports other functions
export function chatHelper(method, state) {
  if (method == 'onInfinityScrolled') return (...params) => onInfinityScrolled(state, ...params);
  if (method == 'onInfinityVisibility') return (...params) => onInfinityVisibility(state, ...params);
  if (method == 'onMessageClick') return (...params) => onMessageClick(state, ...params);
  if (method == 'onVideoLinkClick') return (...params) => onVideoLinkClick(state, ...params);
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

// Internal
function maybeSendVideoUrl(conversation, videoUrl) {
  videoUrl = new URL(videoUrl, location.href).href;
  const messages = conversation.messages;
  const alreadySent = messages.toArray().slice(-20).reverse().find(msg => msg.message.indexOf(videoUrl) != -1);
  if (alreadySent && alreadySent.ts.toEpoch() > new Time().toEpoch() - 600) return;
  conversation.send({method: 'send', message: videoUrl});
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
function onMessageActionClick({conversation}, e, action) {
  e.preventDefault();
  if (action[1] == 'details') {
    const msg = conversation.messages.get(action[2]);
    msg.showDetails = !msg.showDetails;
    conversation.messages.update({messages: true});
  }
  else if (action[1] == 'close') {
    conversation.send('/close ' + (action[2] ? decodeURIComponent(action[2]) : conversation.conversation_id));
    route.go('/settings/conversation');
  }
  else if (action[1] == 'join') {
    conversation.send('/join ' + (action[2] ? decodeURIComponent(action[2]) : conversation.conversation_id));
  }
  else {
    console.warn('Unhandled onMessageActionClick', action);
  }
}

// Available through chatHelper()
function onMessageClick({conversation, user}, e) {
  const aEl = e.target.closest('a');

  // Make sure embed links are opened in a new tab/window
  if (aEl && !aEl.target && e.target.closest('.embed')) aEl.target = '_blank';

  // Proxy video links
  const videoLink = aEl && document.querySelector('[target="convos_video"][href="' + aEl.href + '"]');
  if (videoLink) return onVideoLinkClick({conversation, user}, e, videoLink);

  // Expand/collapse pastebin, except when clicking on a link
  const pasteMetaEl = e.target.closest('.le-meta');
  if (pasteMetaEl) return aEl || pasteMetaEl.parentNode.classList.toggle('is-expanded');

  // Special links with actions in #hash
  const action = aEl && aEl.href.match(/#(action:.+)/);
  if (action) return onMessageActionClick({conversation}, e, action[1].split(':', 3));

  // Show images in full screen
  if (tagNameIs(e.target, 'img')) return showFullscreen(e, e.target);
  if (aEl && aEl.classList.contains('le-thumbnail')) return showFullscreen(e, aEl.querySelector('img'));
}

// Available through chatHelper()
function onVideoLinkClick({conversation, user}, e, aEl) {
  /*
   * Example aEl.href:
   * 1. "#action:video"
   * 2. https://convos.chat/video/meet.jit.si/irc-localhost-whatever?nick=superman
   * 3. https://meet.jit.si/irc-freenode-superman-and-superwoman
   */

  if (!aEl) aEl = e.target.closest('a');

  const videoButtonClicked = aEl.href.indexOf('#action:video') != -1;
  if (videoWindow.close() && videoButtonClicked) return e.preventDefault();

  const renderInsideConvos = aEl.closest('.le-provider-convosapp') || aEl.closest('.le-provider-jitsi');
  const chatParams = {nick: conversation.participants.me().nick};
  if (videoButtonClicked) {
    const videoUrl = new URL(user.videoService);
    videoUrl.pathname += '/' + videoName(conversation);
    videoUrl.pathname = videoUrl.pathname.replace(/\/+/g, '/');
    maybeSendVideoUrl(conversation, videoUrl.toString());
    e.preventDefault();
    videoWindow.open(route.urlFor('/video/' + videoUrl.hostname + '/' + videoName(conversation), chatParams));
  }
  else if (aEl.href.indexOf('/video/') != -1) {
    const url = new URL(aEl.href);
    e.preventDefault();
    videoWindow.open(route.urlFor(url.pathname.replace(/.*?\/video\//, '/video/'), chatParams));
  }
  else if (renderInsideConvos) {
    const url = new URL(aEl.href);
    e.preventDefault();
    videoWindow.open(route.urlFor('/video/' + url.hostname + url.pathname, chatParams));
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
  const str = conversation.frozen ? conversation.frozen : conversation.topic;
  return str || (conversation.is('private') ? 'Private conversation.' : 'No topic is set.');
}

// Internal
function videoName(conversation) {
  const name = conversation.is('private') ? conversation.participants.nicks().sort().join('-and-') : conversation.title;
  return encodeURIComponent(name);
}
