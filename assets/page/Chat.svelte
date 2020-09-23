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

const rtc = getContext('rtc');
const socket = getContext('socket');
const user = getContext('user');

const dragAndDrop = new DragAndDrop();

let chatInput;
let connection = user.notifications;
let dialog = user.notifications;
let now = new Time();
let onLoadHash = '';
let unsubscribe = {};

$: setDialogFromRoute($route);
$: setDialogFromUser($user);
$: messages = renderMessages({dialog: $dialog, expandUrlToMedia: $viewport.expandUrlToMedia, from: $connection.nick, waiting: Array.from($socket.waiting.values())});
$: notConnected = $dialog.frozen ? true : false;
$: if (!$route.hash && !$dialog.historyStopAt) dialog.load({});

onMount(() => {
  dragAndDrop.attach(document.querySelector('.main'), chatInput);
});

onDestroy(() => {
  Object.keys(unsubscribe).forEach(name => unsubscribe[name]());
  dragAndDrop.detach();
  rtc.hangup();
});

function onMessageClick(e) {
  const aEl = e.target.closest('a');
  if (aEl && e.target.closest('.embed')) aEl.target = '_blank';
  if (aEl && !aEl.classList.contains('le-thumbnail') && !aEl.classList.contains('onclick')) return;

  const pasteMetaEl = e.target.closest('.le-meta');
  if (aEl) e.preventDefault();
  if (pasteMetaEl) return pasteMetaEl.parentNode.classList.toggle('is-expanded');
  if (tagNameIs(e.target, 'img')) return viewport.showFullscreen(e.target);
  if (aEl && aEl.classList.contains('le-thumbnail')) return viewport.showFullscreen(aEl.querySelector('img'));
  if (!aEl) return;

  const messageEl = e.target.closest('.message');
  const message = messageEl && messages[messageEl.dataset.index];
  const action = aEl.href.split('#')[1];
  if (action.indexOf('input:') == 0) return chatInput.add(message.from);
  if (action == 'remove') return socket.deleteWaitingMessage(message.id);
  if (action == 'resend') return socket.send(socket.getWaitingMessages([message.id])[0]);
  if (action == 'toggleDetails') return q(messageEl, '.embed.for-jsonhtmlify', el => el.classList.toggle('hidden'));
}

function onRendered(e) {
  const {infinityEl, scrollTo} = e.detail;
  scrollTo(route.hash ? '.message[data-ts="' + route.hash + '"]' : -1);
  renderFocusedEl(infinityEl, onLoadHash == route.hash);
}

function onScrolled(e) {
  if (!dialog.messages.length) return;
  const {infinityEl, pos, visibleEls} = e.detail;
  const firstVisibleEl = visibleEls[0];
  const lastVisibleEl = visibleEls.slice(-1)[0];

  if (pos == 'top') {
    const before = dialog.messages[0].ts.toISOString();
    route.go(dialog.path + '#' + before, {replace: true});
    if (!dialog.historyStartAt) dialog.load({before});
  }
  else if (pos == 'bottom') {
    const after = dialog.messages.slice(-1)[0].ts.toISOString();
    route.go(dialog.path + (dialog.historyStopAt ? '' : '#' + lastVisibleEl.dataset.ts), {replace: true});
    if (!dialog.historyStopAt) dialog.load({after});
  }
  else if (firstVisibleEl && firstVisibleEl.dataset.ts) {
    route.go(dialog.path + '#' + firstVisibleEl.dataset.ts, {replace: true});
  }
}

function renderFocusedEl(infinityEl, add) {
  const focusEl = add && route.hash && infinityEl.querySelector('.message[data-ts="' + route.hash + '"]');
  q(infinityEl, '.has-focus', (el) => el.classList.remove('has-focus'));
  if (focusEl) focusEl.classList.add('has-focus');
}

function setDialogFromRoute(route) {
  const [connection_id, dialog_id] = ['connection_id', 'dialog_id'].map(k => route.param(k));
  if (dialog.connection_id == connection_id && dialog.dialog_id == dialog_id) return;
  user.setActiveDialog({connection_id, dialog_id}); // Triggers setDialogFromUser()
}

function setDialogFromUser(user) {
  if (user.activeDialog == dialog) return;
  if (unsubscribe.dialog) unsubscribe.dialog();
  if (unsubscribe.markAsRead) unsubscribe.markAsRead();

  dialog = user.activeDialog;
  connection = user.findDialog({connection_id: dialog.connection_id}) || dialog;
  now = new Time();
  unsubscribe.dialog = dialog.subscribe(d => { dialog = d });
  unsubscribe.markAsRead = dialog.markAsRead.bind(dialog);
  route.update({title: dialog.title});
  rtc.hangup();

  onLoadHash = isISOTimeString(route.hash) && route.hash || '';
  if (onLoadHash) return dialog.load({around: onLoadHash});
  if (!dialog.historyStopAt) return dialog.load({around: now.toISOString()});
}
</script>

<ChatHeader>
  <h1><a href="#activeMenu:{dialog.connection_id ? 'settings' : 'nav'}" tabindex="-1">{l(dialog.name)}</a></h1>
  <span class="chat-header__topic">{topicOrStatus(connection, dialog)}</span>
  {#if $rtc.enabled && $dialog.dialog_id}
    {#if $rtc.localStream.id && $rtc.constraints.video}
      <Button icon="video-slash" tooltip="{l('Hangup')}" disabled="{notConnected}" on:click="{e => rtc.hangup()}"/>
    {:else}
      <Button icon="video" tooltip="{l('Call')}" disabled="{notConnected}" on:click="{e => rtc.call(dialog, {audio: true, video: true})}"/>
    {/if}
  {/if}
  <a href="#activeMenu:{dialog.connection_id ? 'settings' : 'nav'}" class="btn has-tooltip can-toggle" class:is-toggled="{$route.activeMenu == 'settings'}" data-tooltip="{l('Settings')}"><Icon name="tools"/><Icon name="times"/></a>
</ChatHeader>

<InfinityScroll class="main is-above-chat-input" on:rendered="{onRendered}" on:scrolled="{onScrolled}">
  <!-- status -->
  {#if $dialog.is('loading')}
    <div class="message__status-line for-loading has-pos-top"><span><Icon name="spinner" animation="spin"/> <i>{l('Loading...')}</i></span></div>
  {/if}
  {#if $dialog.historyStartAt && !$dialog.is('not_found')}
    <div class="message__status-line for-start-of-history"><span><Icon name="calendar-alt"/> <i>{l('Started chatting on %1', $dialog.historyStartAt.getHumanDate())}</i></span></div>
  {/if}

  <!-- welcome message -->
  {#if $dialog.messages.length < 10 && !$dialog.is('not_found')}
    {#if $dialog.is_private}
      <ChatMessage>{@html lmd('This is a private conversation with "%1".', $dialog.name)}</ChatMessage>
    {:else}
      <ChatMessage>{@html lmd($dialog.topic ? 'Topic for %1 is: %2': 'No topic is set for %1.', $dialog.name, $dialog.topic)}</ChatMessage>
      {#if $dialog.nParticipants == 1}
        <ChatMessage same="{true}">{l('You are the only participant in this conversation.')}</ChatMessage>
      {:else}
        <ChatMessage same="{true}">{@html lmd('There are %1 [participants](%2) in this conversation.', $dialog.nParticipants, $dialog.path + '#activeMenu:settings')}</ChatMessage>
      {/if}
    {/if}
  {/if}

  <!-- messages -->
  {#each messages as message, i}
    {#if message.dayChanged}
      <div class="message__status-line for-day-changed"><span><Icon name="calendar-alt"/> <i>{message.ts.getHumanDate()}</i></span></div>
    {/if}

    {#if i && i == $dialog.messages.length - $dialog.unread}
      <div class="message__status-line for-last-read"><span><Icon name="comments"/> {l('New messages')}</span></div>
    {/if}

    <div class="{message.className}" data-index="{i}" data-ts="{message.ts.toISOString()}" on:click="{onMessageClick}">
      <Icon name="pick:{message.fromId}" color="{message.color}"/>
      <div class="message__ts has-tooltip" data-content="{message.ts.format('%H:%M')}"><div>{message.ts.toLocaleString()}</div></div>
      <a href="#input:{message.from}" class="message__from onclick" style="color:{message.color}" tabindex="-1">{message.from}</a>
      <div class="message__text">
        {#if message.waitingForResponse === false}
          <a href="#remove" class="pull-right has-tooltip onclick" data-tooltip="{l('Remove')}"><Icon name="times-circle"/></a>
          <a href="#resend" class="pull-right has-tooltip onclick" data-tooltip="{l('Resend')}"><Icon name="sync-alt"/></a>
        {:else if !message.waitingForResponse && message.canToggleDetails}
          <a href="#toggleDetails" class="onclick"><Icon name="{message.type == 'error' ? 'exclamation-circle' : 'info-circle'}"/></a>
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
  {#if $connection.is('not_found') && !$dialog.dialog_id}
    <h2>{l('Connection does not exist.')}</h2>
    <p>{l('Do you want to create the connection "%1"?', $connection.connection_id)}</p>
    <p>
      <Link href="/settings/connection?server={encodeURIComponent($dialog.connection_id)}&dialog={encodeURIComponent($dialog.dialog_id)}" class="btn"><Icon name="thumbs-up"/> {l('Yes')}</Link>
      <Link href="/chat" class="btn"><Icon name="thumbs-down"/> {l('No')}</Link>
    </p>
  {:else if $dialog.is('not_found')}
    <h2>{l('You are not part of this conversation.')}</h2>
    <p>{l('Do you want to chat with "%1"?', $dialog.dialog_id)}</p>
    <p>
      <Button type="button" icon="thumbs-up" on:click="{() => dialog.send('/join ' + $dialog.dialog_id)}"><span>{l('Yes')}</span></Button>
      <Link href="/chat" class="btn"><Icon name="thumbs-down"/><span>{l('No')}</span></Link>
    </p>
  {:else if !$connection.is('unreachable') && $connection.frozen}
    <ChatMessage type="error">{@html lmd('Disconnected. Your connection %1 can be edited in [settings](%2).', $connection.name, $connection.path + '#activeMenu:settings')}</ChatMessage>
  {:else if $dialog.frozen && !$dialog.is('locked')}
    <ChatMessage type="error">{topicOrStatus($connection, $dialog).replace(/\.$/, '') || l($dialog.frozen)}</ChatMessage>
  {/if}
  {#if $dialog.is('loading')}
    <div class="message__status-line for-loading has-pos-bottom"><span><Icon name="spinner" animation="spin"/> <i>{l('Loading...')}</i></span></div>
  {/if}
  {#if !$dialog.historyStopAt && $dialog.messages.length}
    <div class="message__status-line for-jump-to-now"><a href="{dialog.path}"><Icon name="external-link-alt"/> {l('Jump to %1', now.format('%b %e %H:%M'))}</a></div>
  {/if}
</InfinityScroll>

<ChatInput dialog="{dialog}" bind:this="{chatInput}"/>
<ChatParticipants dialog="{dialog}"/>
