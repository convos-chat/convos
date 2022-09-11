<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatMessage from '../components/ChatMessage.svelte';
import ConnectionSettings from '../components/ConnectionSettings.svelte';
import ConversationSettings from '../components/ConversationSettings.svelte';
import DragAndDrop from '../js/DragAndDrop';
import Icon from '../components/Icon.svelte';
import InfinityScroll from '../components/InfinityScroll.svelte';
import Link from '../components/Link.svelte';
import Time from '../js/Time';
import {activeMenu, viewport} from '../store/viewport';
import {awayMessage, topicOrStatus} from '../js/chatHelpers';
import {fade} from 'svelte/transition';
import {getContext, onDestroy, onMount} from 'svelte';
import {isISOTimeString} from '../js/Time';
import {l, lmd} from '../store/I18N';
import {modeClassNames} from '../js/util';
import {onInfinityScrolled, onInfinityVisibility} from '../js/chatHelpers';
import {notify} from '../js/Notify';
import {route} from '../store/Route';

export let connection_id = '';
export let conversation_id = '';
export let title = 'Chat';

const dragAndDrop = new DragAndDrop();
const user = getContext('user');

let connection = user.notifications;
let conversation = user.notifications;
let messages = conversation.messages;
let participants = conversation.participants;
let now = new Time();
let unsubscribe = {};
let focusChatInput, fillIn, uploader, uploadProgress;
let timestampFromUrl = '';

$: setConversationFromRoute(connection_id, conversation_id);
$: setConversationFromUser($user);
$: messages.update({expandUrlToMedia: $user.expandUrlToMedia});
$: conversationName = encodeURIComponent($conversation.name);
$: title = $conversation.title;
$: if (!$route.hash && !$conversation.historyStopAt) conversation.load({});

onMount(() => dragAndDrop.attach(document.querySelector('.main'), uploader));

onDestroy(() => {
  Object.keys(unsubscribe).forEach(name => unsubscribe[name]());
  dragAndDrop.detach();
});

export function conversationJoin(e) {
  e.preventDefault();
  const aEl = e.target.closest('a');
  conversation.send('/join ' + decodeURIComponent(aEl.hash.replace(/^#?action:join:/, '')));
}

export function conversationClose(e) {
  e.preventDefault();
  conversation.send('/close ' + conversation.conversation_id);
  route.go('/settings/conversation');
}

function conversationToUri() {
  const [scheme, host] = $conversation.connection_id.split('-');
  return scheme + '://' + host + '/' + conversationName + '?tls=1';
}

function onFocus() {
  if (conversation.notifications || conversation.unread) conversation.markAsRead();
}

function setConversationFromRoute(connection_id, conversation_id) {
  if (conversation.connection_id == connection_id && conversation.conversation_id == conversation_id) return;
  user.setActiveConversation({connection_id, conversation_id}); // Triggers setConversationFromUser()
}

function setConversationFromUser(user) {
  if (user.activeConversation == conversation) return;
  if (unsubscribe.conversation) unsubscribe.conversation();
  if (unsubscribe.unread) unsubscribe.unread();

  conversation = user.activeConversation;
  messages = conversation.messages;
  participants = conversation.participants;
  connection = user.findConversation({connection_id: conversation.connection_id}) || conversation;
  now = new Time();
  unsubscribe.conversation = conversation.subscribe(d => { conversation = d });
  unsubscribe.unread = () => conversation.update({unread: 0});
  conversation.markAsRead();

  timestampFromUrl = isISOTimeString(route.hash) && route.hash || '';
  if (timestampFromUrl) return conversation.load({around: timestampFromUrl});
  if (!conversation.historyStopAt) return conversation.load({around: now.toISOString()});
}
</script>

<svelte:window on:focus={onFocus}/>

<ChatHeader>
  <h1 class="ellipsis"><a href="#settings" on:click="{activeMenu.toggle}">{$l(conversation.name)}</a></h1>
  <span class="chat-header__topic ellipsis">{topicOrStatus($connection, $conversation)}</span>
  {#if !$conversation.is('not_found')}
    <a href="#settings" class="btn-hallow can-toggle" class:is-active="{$activeMenu == 'settings'}" on:click="{activeMenu.toggle}">
      <Icon name="users-cog"/><Icon name="times"/>
    </a>
  {/if}
</ChatHeader>

{#if $activeMenu == 'settings'}
  {#if conversation_id}
    <ConversationSettings conversation="{conversation}" transition="{{duration: 250, x: $viewport.isSingleColumn ? $viewport.width : 0}}"/>
  {:else}
    <ConnectionSettings conversation="{conversation}" transition="{{duration: 250, x: $viewport.isSingleColumn ? $viewport.width : 0}}"/>
  {/if}
{/if}

<InfinityScroll class="main is-above-chat-input" on:scrolled="{e => onInfinityScrolled(e, {conversation})}" on:visibility="{e => onInfinityVisibility(e, {conversation, timestampFromUrl})}">
  <!-- welcome message -->
  {#if $messages.length < 10 && !$conversation.is('not_found')}
    {#if $conversation.is('private')}
      <p><Icon name="info-circle"/> {@html $lmd('This is a private conversation with "%1".', $conversation.name)}</p>
    {:else if !$conversation.frozen}
      <p>
        <Icon name="info-circle"/> 
        {@html $lmd($conversation.topic ? 'Topic for %1 is: %2': 'No topic is set for %1.', $conversation.name, $conversation.topic)}
      </p>
      <p>
        <Icon name="info-circle"/> 
        {#if $participants.length == 1}
          {$l('You are the only participant in this conversation.')}
        {:else}
          {@html $lmd('There are %1 participants in this conversation.', $participants.length)}
        {/if}
      </p>
    {/if}
  {/if}

  <!-- status -->
  {#if $conversation.is('loading') && $messages.length > 10}
    <div class="message__status-line for-loading has-pos-top"><span><Icon name="spinner" animation="spin"/> <i>{$l('Loading...')}</i></span></div>
  {/if}
  {#if $conversation.historyStartAt && !$conversation.is('not_found') && $messages.length}
    <div class="message__status-line for-start-of-history"><span><Icon name="calendar-alt"/> <i>{$l('Started chatting on %1', $conversation.historyStartAt.getHumanDate())}</i></span></div>
  {/if}

  <!-- messages -->
  {#each $messages.render() as message, i}
    {#if message.dayChanged}
      <div class="message__status-line for-day-changed"><span><Icon name="calendar-alt"/> <i>{message.ts.getHumanDate()}</i></span></div>
    {/if}

    {#if i && i == $messages.length - $conversation.unread}
      <div class="message__status-line for-last-read"><span><Icon name="comments"/> {$l('New messages')}</span></div>
    {/if}

    <ChatMessage conversation="{conversation}" message="{message}" on:mention="{e => fillIn(e.detail)}"/>
  {/each}

  <!-- status -->
  {#if $connection.is('not_found')}
    <h2>{$l('Connection does not exist.')}</h2>
    <p>{$l('Do you want to create the connection "%1"?', $connection.connection_id)}</p>
    <p>
      <Link href="/settings/connections?uri={encodeURIComponent(conversationToUri($conversation))}" class="btn"><Icon name="thumbs-up"/> {$l('Yes')}</Link>
      <Link href="/settings/connections" class="btn is-secondary"><Icon name="thumbs-down"/> {$l('No')}</Link>
    </p>
  {:else if $conversation.is('not_found')}
    <h2>{$l('You are not part of this conversation.')}</h2>
    <p>{$l('Do you want to chat with "%1"?', $conversation.name)}</p>
    <p>
      <Link href="#action:join:{conversationName}" class="btn" on:click="{conversationJoin}"><Icon name="thumbs-up"/> <span>{$l('Yes')}</span></Link>
      <Link href="/settings/conversation" class="btn is-secondary"><Icon name="thumbs-down"/> <span>{$l('No')}</span></Link>
    </p>
  {:else if !$connection.is('unreachable') && $connection.frozen}
    <div class="message is-highlighted" on:click="{activeMenu.toggle}">
      <div class="message__text"><Icon name="exclamation-triangle"/> {@html $lmd('Disconnected. Your connection %1 can be edited in [settings](%2).', $connection.name, '/chat/' + $connection.connection_id + '#settings')}</div>
    </div>
  {:else if $conversation.frozen && $conversation.is('pending')}
    <h2>{$l('You are invited to join %1.', conversation.name)}</h2>
    <p>{$l('Do you want to join?')}</p>
    <p>
      <Link href="#action:join:{conversationName}" class="btn" on:click="{conversationJoin}"><Icon name="thumbs-up"/> <span>{$l('Yes')}</span></Link>
      <Link href="#action:close:{conversationName}" class="btn is-secondary" on:click="{conversationClose}"><Icon name="thumbs-down"/> <span>{$l('No')}</span></Link>
    </p>
  {:else if $conversation.frozen && !$conversation.is('locked')}
    <div class="message is-highlighted">
      <div class="message__text"><Icon name="exclamation-triangle"/> {topicOrStatus($connection, $conversation)}</div>
    </div>
  {/if}

  {#if uploadProgress}
    <div class="message" transition:fade="{{duration: 200}}">
      <div>{$l('Uploading %1...', uploader.file.name)}</div>
      <div class="progress">
        <div class="progress__bar" style="width:{uploadProgress}%;">{uploadProgress}%</div>
      </div>
    </div>
  {/if}

  {#if notify.wantNotifications === null}
    <div class="message is-highlighted">
      <div class="message__text"><Icon name="info-circle"/> {@html $lmd('Go to "[account settings](%1)" to enable or disable notifications.', '/settings/account')}</div>
    </div>
  {/if}

  {#if $conversation.is('loading')}
    <div class="message__status-line for-loading has-pos-bottom"><span><Icon name="spinner" animation="spin"/> <i>{$l('Loading...')}</i></span></div>
  {/if}
  {#if !$conversation.historyStopAt && $messages.length}
    <div class="message__status-line for-jump-to-now"><a href="{conversation.path}"><Icon name="external-link-alt"/> {$l('Jump to %1', now.format('%b %e %H:%M'))}</a></div>
  {/if}
</InfinityScroll>

<ChatInput conversation="{conversation}" bind:fillIn bind:focus="{focusChatInput}" bind:uploader bind:uploadProgress/>

{#if $viewport.hasRightColumn && $participants.length && !$conversation.is('not_found')}
  <div class="sidebar-right">
    <h3>{$l('Participants (%1)', $participants.length)}</h3>
    <nav class="sidebar-right__nav" on:click="{conversationJoin}">
      {#each $participants.toArray() as participant}
        <a href="#action:join:{participant.nick}" class="participant {modeClassNames(participant.modes)}">
          <Icon name="pick:{participant.nick}" family="solid" color="{participant.color}"/>
          <span>{participant.nick}</span>
        </a>
      {/each}
    </nav>

    {#if $conversation.is('private') && $conversation.info.nick}
      <h3>{$l('Information')}</h3>
      <p>{@html $lmd(...awayMessage($conversation.info))}</p>
    {/if}
  </div>
{/if}
