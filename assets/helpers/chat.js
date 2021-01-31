import Time from '../js/Time';
import {q, showFullscreen, tagNameIs} from '../js/util';
import {route} from '../store/Route';

// Exports other functions
export function chatHelper(method, state) {
  if (method == 'onInfinityScrolled') return (...params) => onInfinityScrolled(state, ...params);
  if (method == 'onInfinityVisibility') return (...params) => onInfinityVisibility(state, ...params);
  if (method == 'onVideoLinkClick') return (...params) => onVideoLinkClick(state, ...params);
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
export function onInfinityVisibility({messages, onLoadHash}, e) {
  const {infinityEl, scrollHeightChanged, scrollTo, visibleEls, visibleElsChanged} = e.detail;
  if (scrollHeightChanged) {
    scrollTo(route.hash ? '.message[data-ts="' + route.hash + '"]' : -1);
    renderFocusedEl(infinityEl, onLoadHash == route.hash);
  }
  if (visibleElsChanged) {
    visibleEls.forEach(el => messages.render(el.dataset.index));
  }
}

// Internal
function onMessageActionClick(e, action) {
  if (action[0] == 'activeMenu') return true; // Bubble up to Route.js _onClick(e)
  e.preventDefault();
  const messageEl = e.target.closest('.message');
  const message = messageEl && messages.get(messageEl.dataset.index);
  if (action[1] == 'join') return conversation.send('/join ' + message.from);
  if (action[1] == 'remove') return socket.deleteWaitingMessage(message.id);
  if (action[1] == 'resend') return socket.send(socket.getWaitingMessages([message.id])[0]);

  if (action[1] == 'details') {
    const msg = messages.get(messageEl.dataset.index);
    msg.showDetails = !msg.showDetails;
    messages.update({messages: true});
  }
}

// Exported
export function onMessageClick(e) {
  const aEl = e.target.closest('a');

  // Make sure embed links are opened in a new tab/window
  if (aEl && !aEl.target && e.target.closest('.embed')) aEl.target = '_blank';

  // Proxy clicks
  const messageEl = e.target.closest('.message');
  const proxyEl = aEl && messageEl && document.querySelector('[data-handle-link="' + aEl.href + '"]');
  if (proxyEl) return [e.preventDefault(), proxyEl.click()];

  // Expand/collapse pastebin, except when clicking on a link
  const pasteMetaEl = e.target.closest('.le-meta');
  if (pasteMetaEl) return aEl || pasteMetaEl.parentNode.classList.toggle('is-expanded');

  // Special links with actions in #hash
  const action = aEl && aEl.href.match(/#(activeMenu|action:[\w:]+)/);
  if (action) return onMessageActionClick(e, action[1].split(':', 3));

  // Show images in full screen
  if (tagNameIs(e.target, 'img')) return showFullscreen(e, e.target);
  if (aEl && aEl.classList.contains('le-thumbnail')) return showFullscreen(e, aEl.querySelector('img'));
}

// Available through chatHelper()
function onVideoLinkClick({conversation}, e) {
  const messages = conversation.messages;
  const videoInfo = conversation.videoInfo();

  e.preventDefault();
  if (conversation.window) return conversation.window.close();
  conversation.openWindow(videoInfo.convosUrl, videoInfo.roomName);

  const alreadySent = messages.toArray().slice(-30).reverse().find(msg => msg.message.indexOf(videoInfo.realUrl) != -1);
  const send = !alreadySent || alreadySent.ts.toEpoch() < new Time().toEpoch() - 600;
  if (send) conversation.send({method: 'send', message: videoInfo.realUrl});
}

// Exported
export function renderEmbed(el, embed) {
  const parentNode = embed.nodes[0] && embed.nodes[0].parentNode;
  if (parentNode) {
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
  return str || (conversation.is_private ? 'Private conversation.' : 'No topic is set.');
}
