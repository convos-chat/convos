import {q} from '../js/util';
import {i18n} from '../store/I18N';
import {route} from '../store/Route';

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

export function conversationUrl(message) {
  const path = ['', 'chat', message.connection_id];
  if (message.conversation_id) path.push(message.conversation_id);
  return route.urlFor(path.map(encodeURIComponent).join('/') + '#' + message.ts.toISOString());
}

export function gotoConversation(e) {
  if (e.target.closest('a')) return;
  e.preventDefault();
  route.go(e.target.closest('.message').querySelector('a').href);
}

export function onInfinityScrolled(e, {conversation}) {
  const visibleEls = e.detail.visibleEls.filter(el => el.dataset.ts);
  if (!visibleEls.length) return;

  const go = (hash) => route.go(conversation.path + (hash.length ? '#' + hash : ''), {replace: true});
  const pos = e.detail.pos;
  if (pos === 'top') {
    const before = visibleEls[0].dataset.ts;
    if (!conversation.historyStartAt) conversation.load({before});
    go(before);
  }
  else if (pos === 'bottom') {
    const after = visibleEls.slice(-1)[0].dataset.ts;
    if (!conversation.historyStopAt) conversation.load({after});
    go(conversation.historyStopAt ? '' : after);
  }
  else {
    go(visibleEls[0].dataset.ts);
  }
}

export function onInfinityVisibility(e, {conversation, timestampFromUrl}) {
  const {infinityEl, scrollHeightChanged, scrollTo, visibleEls, visibleElsChanged} = e.detail;
  const messages = conversation.messages;
  const hasScrollbar = infinityEl.scrollHeight > infinityEl.offsetHeight;

  if (!hasScrollbar && messages.length) {
    conversation.load({before: messages.get(0).ts.toISOString()});
  }
  if (scrollHeightChanged) {
    scrollTo(route.hash ? '.message[data-ts="' + route.hash + '"]' : -1);
    renderInfinityFocusedEl(infinityEl, timestampFromUrl === route.hash);
  }
  if (visibleElsChanged) {
    visibleEls.forEach(el => messages.render(el.dataset.index));
  }
}

function renderInfinityFocusedEl(infinityEl, add) {
  const focusEl = add && route.hash && infinityEl.querySelector('.message[data-ts="' + route.hash + '"]');
  q(infinityEl, '.has-focus', (el) => el.classList.remove('has-focus'));
  if (focusEl) focusEl.classList.add('has-focus');
}

export function topicOrStatus(connection, conversation) {
  if (conversation.is('not_found')) return '';
  if (connection.frozen) return connection.frozen;
  if (connection === conversation) return 'Connection messages.';
  if (conversation.info.away) return conversation.info.away;
  if (conversation.info.idle_for) return i18n.l('User has been idle for %1s.', conversation.info.idle_for);
  const str = conversation.frozen ? conversation.frozen : conversation.topic;
  return str || (conversation.is('private') ? 'Private conversation.' : 'No topic is set.');
}
