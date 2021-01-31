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
import {chatHelper, onMessageClick, renderEmbed, topicOrStatus} from '../helpers/chat';
import {getContext, onDestroy, onMount} from 'svelte';
import {isISOTimeString} from '../js/Time';
import {l, lmd} from '../store/I18N';
import {route} from '../store/Route';

export let title = 'Chat';

const dragAndDrop = new DragAndDrop();
const socket = getContext('socket');
const user = getContext('user');

let connection = user.notifications;
let conversation = user.notifications;
let messages = conversation.messages;
let now = new Time();
let onLoadHash = '';
let unsubscribe = {};
let uploader;

$: setConversationFromRoute($route);
$: setConversationFromUser($user);
$: notConnected = $conversation.frozen ? true : false;
$: title = $conversation.title;
$: videoInfo = $conversation.videoInfo();
$: if (!$route.hash && !$conversation.historyStopAt) conversation.load({});

$: onInfinityScrolled = chatHelper('onInfinityScrolled', {conversation});
$: onInfinityVisibility = chatHelper('onInfinityVisibility', {messages, onLoadHash});
$: onVideoLinkClick = chatHelper('onVideoLinkClick', {conversation});

onMount(() => {
  dragAndDrop.attach(document.querySelector('.main'), uploader);
});

onDestroy(() => {
  Object.keys(unsubscribe).forEach(name => unsubscribe[name]());
  dragAndDrop.detach();
});

function setConversationFromRoute($route) {
  const [connection_id, conversation_id] = ['connection_id', 'conversation_id'].map(k => $route.param(k));
  if (conversation.connection_id == connection_id && conversation.conversation_id == conversation_id) return;
  user.setActiveConversation({connection_id, conversation_id}); // Triggers setConversationFromUser()
}

function setConversationFromUser(user) {
  if (user.activeConversation == conversation) return;
  if (unsubscribe.conversation) unsubscribe.conversation();
  if (unsubscribe.markAsRead) unsubscribe.markAsRead();

  conversation = user.activeConversation;
  messages = conversation.messages;
  connection = user.findConversation({connection_id: conversation.connection_id}) || conversation;
  now = new Time();
  unsubscribe.conversation = conversation.subscribe(d => { conversation = d });
  unsubscribe.markAsRead = conversation.markAsRead.bind(conversation);

  onLoadHash = isISOTimeString(route.hash) && route.hash || '';
  if (onLoadHash) return conversation.load({around: onLoadHash});
  if (!conversation.historyStopAt) return conversation.load({around: now.toISOString()});
}
</script>

<ChatHeader>
  <h1><a href="#activeMenu:{conversation.connection_id ? 'settings' : 'nav'}" tabindex="-1">{$l(conversation.name)}</a></h1>
  <span class="chat-header__topic">{topicOrStatus(connection, conversation)}</span>
  {#if videoInfo.convosUrl}
    <a href="{videoInfo.convosUrl}" on:click="{onVideoLinkClick}" target="{videoInfo.roomName}" data-handle-link="{videoInfo.realUrl}" class="btn has-tooltip" tooltip="{$l('Start video conference')}"><Icon name="{videoInfo.icon}"/></a>
  {/if}
  <a href="#activeMenu:{conversation.connection_id ? 'settings' : 'nav'}" class="btn has-tooltip can-toggle" class:is-toggled="{$route.activeMenu == 'settings'}" data-tooltip="{$l('Settings')}"><Icon name="tools"/><Icon name="times"/></a>
</ChatHeader>

<InfinityScroll class="main is-above-chat-input" on:scrolled="{onInfinityScrolled}" on:visibility="{onInfinityVisibility}">
  <!-- status -->
  {#if $conversation.is('loading')}
    <div class="message__status-line for-loading has-pos-top"><span><Icon name="spinner" animation="spin"/> <i>{$l('Loading...')}</i></span></div>
  {/if}
  {#if $conversation.historyStartAt && !$conversation.is('not_found')}
    <div class="message__status-line for-start-of-history"><span><Icon name="calendar-alt"/> <i>{$l('Started chatting on %1', $conversation.historyStartAt.getHumanDate())}</i></span></div>
  {/if}

  <!-- welcome message -->
  {#if $messages.length < 10 && !$conversation.is('not_found')}
    {#if $conversation.is_private}
      <ChatMessage>{@html $lmd('This is a private conversation with "%1".', $conversation.name)}</ChatMessage>
    {:else}
      <ChatMessage>{@html $lmd($conversation.topic ? 'Topic for %1 is: %2': 'No topic is set for %1.', $conversation.name, $conversation.topic)}</ChatMessage>
      {#if $conversation.nParticipants == 1}
        <ChatMessage same="{true}">{$l('You are the only participant in this conversation.')}</ChatMessage>
      {:else}
        <ChatMessage same="{true}">{@html $lmd('There are %1 [participants](%2) in this conversation.', $conversation.nParticipants, $conversation.path + '#activeMenu:settings')}</ChatMessage>
      {/if}
    {/if}
  {/if}

  <!-- messages -->
  {#each $messages.render() as message, i}
    {#if message.dayChanged}
      <div class="message__status-line for-day-changed"><span><Icon name="calendar-alt"/> <i>{message.ts.getHumanDate()}</i></span></div>
    {/if}

    {#if i && i == $messages.length - $conversation.unread}
      <div class="message__status-line for-last-read"><span><Icon name="comments"/> {$l('New messages')}</span></div>
    {/if}

    <div class="{message.className}" class:is-not-present="{!$conversation.findParticipant(message.from)}" class:show-details="{!!message.showDetails}" data-index="{i}" data-ts="{message.ts.toISOString()}" on:click="{onMessageClick}">
      <Icon name="pick:{message.from}" color="{message.color}"/>
      <div class="message__ts has-tooltip" data-content="{message.ts.format('%H:%M')}"><div>{message.ts.toLocaleString()}</div></div>
      <a href="#action:join:{message.from}" class="message__from" style="color:{message.color}" tabindex="-1">{message.from}</a>
      <div class="message__text">
        {#if message.waitingForResponse === false}
          <a href="#action:remove" class="pull-right has-tooltip" data-tooltip="{$l('Remove')}"><Icon name="times-circle"/></a>
          <a href="#action:resend" class="pull-right has-tooltip " data-tooltip="{$l('Resend')}"><Icon name="sync-alt"/></a>
        {:else if !message.waitingForResponse && message.canToggleDetails}
          <a href="#action:details"><Icon name="{message.showDetails ? 'caret-square-up' : 'caret-square-down'}"/></a>
        {/if}
        {@html message.markdown}
      </div>
      {#each message.embeds as embedPromise}
        {#await embedPromise}
          <!-- loading embed -->
        {:then embed}
          <div class="embed {embed.className}" use:renderEmbed="{embed}"/>
        {/await}
      {/each}
    </div>
  {/each}

  <!-- status -->
  {#if $connection.is('not_found') && !$conversation.conversation_id}
    <h2>{$l('Connection does not exist.')}</h2>
    <p>{$l('Do you want to create the connection "%1"?', $connection.connection_id)}</p>
    <p>
      <Link href="/settings/connection?server={encodeURIComponent($conversation.connection_id)}&conversation={encodeURIComponent($conversation.conversation_id)}" class="btn"><Icon name="thumbs-up"/> {$l('Yes')}</Link>
      <Link href="/chat" class="btn"><Icon name="thumbs-down"/> {$l('No')}</Link>
    </p>
  {:else if $conversation.is('not_found')}
    <h2>{$l('You are not part of this conversation.')}</h2>
    <p>{$l('Do you want to chat with "%1"?', $conversation.conversation_id)}</p>
    <p>
      <Button type="button" icon="thumbs-up" on:click="{() => conversation.send('/join ' + $conversation.conversation_id)}"><span>{$l('Yes')}</span></Button>
      <Link href="/chat" class="btn"><Icon name="thumbs-down"/><span>{$l('No')}</span></Link>
    </p>
  {:else if !$connection.is('unreachable') && $connection.frozen}
    <ChatMessage type="error">{@html $lmd('Disconnected. Your connection %1 can be edited in [settings](%2).', $connection.name, '#activeMenu:settings')}</ChatMessage>
  {:else if $conversation.frozen && !$conversation.is('locked')}
    <ChatMessage type="error">{topicOrStatus($connection, $conversation).replace(/\.$/, '') || $l($conversation.frozen)}</ChatMessage>
  {/if}
  {#if $conversation.is('loading')}
    <div class="message__status-line for-loading has-pos-bottom"><span><Icon name="spinner" animation="spin"/> <i>{$l('Loading...')}</i></span></div>
  {/if}
  {#if !$conversation.historyStopAt && $messages.length}
    <div class="message__status-line for-jump-to-now"><a href="{conversation.path}"><Icon name="external-link-alt"/> {$l('Jump to %1', now.format('%b %e %H:%M'))}</a></div>
  {/if}
</InfinityScroll>

<ChatInput conversation="{conversation}" bind:uploader/>
<ChatParticipants conversation="{conversation}"/>
