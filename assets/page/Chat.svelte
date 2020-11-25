<script>
import Button from '../components/form/Button.svelte';
import ChatMessage from '../components/ChatMessage.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatParticipants from '../components/ChatParticipants.svelte';
import DragAndDrop from '../js/DragAndDrop';
import Icon from '../components/Icon.svelte';
import InfinityScroll from '../components/InfinityScroll.svelte';
import Link from '../components/Link.svelte';
import Time from '../js/Time';
import {getContext, onDestroy, onMount} from 'svelte';
import {isISOTimeString} from '../js/Time';
import {l, lmd, topicOrStatus} from '../js/i18n';
import {q, tagNameIs} from '../js/util';
import {renderMessages} from '../js/renderMessages';
import {route} from '../store/Route';
import {viewport} from '../store/Viewport';

const socket = getContext('socket');
const user = getContext('user');

const dragAndDrop = new DragAndDrop();

let connection = user.notifications;
let conversation = user.notifications;
let now = new Time();
let onLoadHash = '';
let uploader;
let unsubscribe = {};

$: setConversationFromRoute($route);
$: setConversationFromUser($user);
$: messages = renderMessages({conversation: $conversation, expandUrlToMedia: $viewport.expandUrlToMedia, from: $connection.nick, waiting: Array.from($socket.waiting.values())});
$: notConnected = $conversation.frozen ? true : false;
$: if (!$route.hash && !$conversation.historyStopAt) conversation.load({});

onMount(() => {
  dragAndDrop.attach(document.querySelector('.main'), uploader);
});

onDestroy(() => {
  Object.keys(unsubscribe).forEach(name => unsubscribe[name]());
  dragAndDrop.detach();
});

function onMessageActionClick(e, action) {
  if (action[0] == 'activeMenu') return true; // Bubble up to Route.js _onClick(e)
  e.preventDefault();
  const messageEl = e.target.closest('.message');
  const message = messageEl && messages[messageEl.dataset.index];
  if (action[1] == 'join') return conversation.send('/join ' + message.from);
  if (action[1] == 'remove') return socket.deleteWaitingMessage(message.id);
  if (action[1] == 'resend') return socket.send(socket.getWaitingMessages([message.id])[0]);
  if (action[1] == 'toggleDetails') return q(messageEl, '.embed.for-jsonhtmlify', el => el.classList.toggle('hidden'));
}

function onMessageClick(e) {
  const aEl = e.target.closest('a');

  // Make sure embed links are opened in a new tab/window
  if (aEl && e.target.closest('.embed')) aEl.target = '_blank';

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

function onRendered(e) {
  const {infinityEl, scrollTo} = e.detail;
  scrollTo(route.hash ? '.message[data-ts="' + route.hash + '"]' : -1);
  renderFocusedEl(infinityEl, onLoadHash == route.hash);
}

function onScrolled(e) {
  if (!conversation.messages.length) return;
  const {infinityEl, pos, visibleEls} = e.detail;
  const firstVisibleEl = visibleEls[0];
  const lastVisibleEl = visibleEls.slice(-1)[0];

  if (pos == 'top') {
    const before = conversation.messages[0].ts.toISOString();
    route.go(conversation.path + '#' + before, {replace: true});
    if (!conversation.historyStartAt) conversation.load({before});
  }
  else if (pos == 'bottom') {
    const after = conversation.messages.slice(-1)[0].ts.toISOString();
    route.go(conversation.path + (conversation.historyStopAt ? '' : '#' + lastVisibleEl.dataset.ts), {replace: true});
    if (!conversation.historyStopAt) conversation.load({after});
  }
  else if (firstVisibleEl && firstVisibleEl.dataset.ts) {
    route.go(conversation.path + '#' + firstVisibleEl.dataset.ts, {replace: true});
  }
}

function renderFocusedEl(infinityEl, add) {
  const focusEl = add && route.hash && infinityEl.querySelector('.message[data-ts="' + route.hash + '"]');
  q(infinityEl, '.has-focus', (el) => el.classList.remove('has-focus'));
  if (focusEl) focusEl.classList.add('has-focus');
}

function setConversationFromRoute(route) {
  const [connection_id, conversation_id] = ['connection_id', 'conversation_id'].map(k => route.param(k));
  if (conversation.connection_id == connection_id && conversation.conversation_id == conversation_id) return;
  user.setActiveConversation({connection_id, conversation_id}); // Triggers setConversationFromUser()
}

function setConversationFromUser(user) {
  if (user.activeConversation == conversation) return;
  if (unsubscribe.conversation) unsubscribe.conversation();
  if (unsubscribe.markAsRead) unsubscribe.markAsRead();

  conversation = user.activeConversation;
  connection = user.findConversation({connection_id: conversation.connection_id}) || conversation;
  now = new Time();
  unsubscribe.conversation = conversation.subscribe(d => { conversation = d });
  unsubscribe.markAsRead = conversation.markAsRead.bind(conversation);
  route.update({title: conversation.title});

  onLoadHash = isISOTimeString(route.hash) && route.hash || '';
  if (onLoadHash) return conversation.load({around: onLoadHash});
  if (!conversation.historyStopAt) return conversation.load({around: now.toISOString()});
}

function showFullscreen(e, el) {
  e.preventDefault();
  viewport.showFullscreen(el);
}
</script>

<ChatHeader>
  <h1><a href="#activeMenu:{conversation.connection_id ? 'settings' : 'nav'}" tabindex="-1">{l(conversation.name)}</a></h1>
  <span class="chat-header__topic">{topicOrStatus(connection, conversation)}</span>
  <a href="#activeMenu:{conversation.connection_id ? 'settings' : 'nav'}" class="btn has-tooltip can-toggle" class:is-toggled="{$route.activeMenu == 'settings'}" data-tooltip="{l('Settings')}"><Icon name="tools"/><Icon name="times"/></a>
</ChatHeader>

<InfinityScroll class="main is-above-chat-input" on:rendered="{onRendered}" on:scrolled="{onScrolled}">
  <!-- status -->
  {#if $conversation.is('loading')}
    <div class="message__status-line for-loading has-pos-top"><span><Icon name="spinner" animation="spin"/> <i>{l('Loading...')}</i></span></div>
  {/if}
  {#if $conversation.historyStartAt && !$conversation.is('not_found')}
    <div class="message__status-line for-start-of-history"><span><Icon name="calendar-alt"/> <i>{l('Started chatting on %1', $conversation.historyStartAt.getHumanDate())}</i></span></div>
  {/if}

  <!-- welcome message -->
  {#if $conversation.messages.length < 10 && !$conversation.is('not_found')}
    {#if $conversation.is_private}
      <ChatMessage>{@html lmd('This is a private conversation with "%1".', $conversation.name)}</ChatMessage>
    {:else}
      <ChatMessage>{@html lmd($conversation.topic ? 'Topic for %1 is: %2': 'No topic is set for %1.', $conversation.name, $conversation.topic)}</ChatMessage>
      {#if $conversation.nParticipants == 1}
        <ChatMessage same="{true}">{l('You are the only participant in this conversation.')}</ChatMessage>
      {:else}
        <ChatMessage same="{true}">{@html lmd('There are %1 [participants](%2) in this conversation.', $conversation.nParticipants, $conversation.path + '#activeMenu:settings')}</ChatMessage>
      {/if}
    {/if}
  {/if}

  <!-- messages -->
  {#each messages as message, i}
    {#if message.dayChanged}
      <div class="message__status-line for-day-changed"><span><Icon name="calendar-alt"/> <i>{message.ts.getHumanDate()}</i></span></div>
    {/if}

    {#if i && i == $conversation.messages.length - $conversation.unread}
      <div class="message__status-line for-last-read"><span><Icon name="comments"/> {l('New messages')}</span></div>
    {/if}

    <div class="{message.className}" data-index="{i}" data-ts="{message.ts.toISOString()}" on:click="{onMessageClick}">
      <Icon name="pick:{message.fromId}" color="{message.color}"/>
      <div class="message__ts has-tooltip" data-content="{message.ts.format('%H:%M')}"><div>{message.ts.toLocaleString()}</div></div>
      <a href="#action:join:{message.from}" class="message__from" style="color:{message.color}" tabindex="-1">{message.from}</a>
      <div class="message__text">
        {#if message.waitingForResponse === false}
          <a href="#action:remove" class="pull-right has-tooltip" data-tooltip="{l('Remove')}"><Icon name="times-circle"/></a>
          <a href="#action:resend" class="pull-right has-tooltip " data-tooltip="{l('Resend')}"><Icon name="sync-alt"/></a>
        {:else if !message.waitingForResponse && message.canToggleDetails}
          <a href="#action:toggleDetails"><Icon name="{message.type == 'error' ? 'exclamation-circle' : 'info-circle'}"/></a>
        {/if}
        {@html message.markdown}
      </div>
      {#each message.embeds as embedPromise}
        {#await embedPromise}
          <!-- loading embed -->
        {:then embed}
          <div class="embed {embed.className}">{@html embed.html}</div>
        {/await}
      {/each}
    </div>
  {/each}

  <!-- status -->
  {#if $connection.is('not_found') && !$conversation.conversation_id}
    <h2>{l('Connection does not exist.')}</h2>
    <p>{l('Do you want to create the connection "%1"?', $connection.connection_id)}</p>
    <p>
      <Link href="/settings/connection?server={encodeURIComponent($conversation.connection_id)}&conversation={encodeURIComponent($conversation.conversation_id)}" class="btn"><Icon name="thumbs-up"/> {l('Yes')}</Link>
      <Link href="/chat" class="btn"><Icon name="thumbs-down"/> {l('No')}</Link>
    </p>
  {:else if $conversation.is('not_found')}
    <h2>{l('You are not part of this conversation.')}</h2>
    <p>{l('Do you want to chat with "%1"?', $conversation.conversation_id)}</p>
    <p>
      <Button type="button" icon="thumbs-up" on:click="{() => conversation.send('/join ' + $conversation.conversation_id)}"><span>{l('Yes')}</span></Button>
      <Link href="/chat" class="btn"><Icon name="thumbs-down"/><span>{l('No')}</span></Link>
    </p>
  {:else if !$connection.is('unreachable') && $connection.frozen}
    <ChatMessage type="error">{@html lmd('Disconnected. Your connection %1 can be edited in [settings](%2).', $connection.name, '#activeMenu:settings')}</ChatMessage>
  {:else if $conversation.frozen && !$conversation.is('locked')}
    <ChatMessage type="error">{topicOrStatus($connection, $conversation).replace(/\.$/, '') || l($conversation.frozen)}</ChatMessage>
  {/if}
  {#if $conversation.is('loading')}
    <div class="message__status-line for-loading has-pos-bottom"><span><Icon name="spinner" animation="spin"/> <i>{l('Loading...')}</i></span></div>
  {/if}
  {#if !$conversation.historyStopAt && $conversation.messages.length}
    <div class="message__status-line for-jump-to-now"><a href="{conversation.path}"><Icon name="external-link-alt"/> {l('Jump to %1', now.format('%b %e %H:%M'))}</a></div>
  {/if}
</InfinityScroll>

<ChatInput conversation="{conversation}" bind:uploader="{uploader}"/>
<ChatParticipants conversation="{conversation}"/>
