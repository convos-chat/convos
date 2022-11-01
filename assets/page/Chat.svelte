<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import ChatParticipants from '../components/ChatParticipants.svelte';
import ChatWelcome from '../components/ChatWelcome.svelte';
import ConnectionSettings from '../components/ConnectionSettings.svelte';
import ConversationSettings from '../components/ConversationSettings.svelte';
import DragAndDrop from '../js/DragAndDrop';
import Icon from '../components/Icon.svelte';
import InfinityScroll from '../components/InfinityScroll.svelte';
import Link from '../components/Link.svelte';
import Time from '../js/Time';
import {activeMenu, viewport} from '../store/viewport';
import {topicOrStatus} from '../js/chatHelpers';
import {fade} from 'svelte/transition';
import {getContext, onDestroy, onMount} from 'svelte';
import {isISOTimeString} from '../js/Time';
import {l, lmd} from '../store/I18N';
import {nbsp, showFullscreen} from '../js/util';
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
let popoverIndex = -1;
let unsubscribe = {};
let focusChatInput, fillIn, uploader, uploadProgress;
let timestampFromUrl = '';
let onClickUnsubscribe;

$: setConversationFromRoute(connection_id, conversation_id);
$: setConversationFromUser($user);
$: messages.update({expandUrlToMedia: $user.expandUrlToMedia});
$: conversationName = encodeURIComponent($conversation.name);
$: title = $conversation.title;
$: if (!$route.hash && !$conversation.historyStopAt) conversation.load({});

onMount(() => {
  dragAndDrop.attach(document.querySelector('.main'), uploader);
  onClickUnsubscribe = route.on('click', onRouteClick);
});

onDestroy(() => {
  onClickUnsubscribe();
  Object.keys(unsubscribe).forEach(name => unsubscribe[name]());
  dragAndDrop.detach();
});

function conversationToUri() {
  const [scheme, host] = $conversation.connection_id.split('-');
  return scheme + '://' + host + '/' + conversationName + '?tls=1';
}

function onFocus() {
  if (conversation.notifications || conversation.unread) conversation.markAsRead();
}

function onRouteClick(e) {
  const aEl = e.target.closest('a[href]');
  if (!aEl || aEl.href.indexOf('popover:') === -1) popoverIndex = -1;
  if (!aEl) return;

  const isThumbnail = aEl.classList.contains('le-thumbnail');
  const preventDefault = aEl.classList.contains('prevent-default');
  if (isThumbnail || preventDefault) e.preventDefault();
  if (isThumbnail) return showFullscreen(e, aEl.querySelector('img'));

  const isSafe = preventDefault || aEl.closest('.embed');
  const action = isSafe && aEl.hash.match(/action:([a-z]+):(.*)$/) || ['all', 'unknown', 'value'];
  action[2] = decodeURIComponent(action[2]);

  if (['close', 'join', 'whois'].indexOf(action[1]) !== -1) {
    conversation.send('/' + action[1] + ' ' + action[2]);
    if (action[1] === 'close') route.go('/settings/conversation');
  }
  else if (action[1] === 'expand') {
    const msg = conversation.messages.get(action[2]);
    msg.expanded = !msg.expanded;
    conversation.messages.update({messages: true});
  }
  else if (action[1] === 'mention') {
    fillIn(action[2]);
  }
  else if (action[1] === 'popover') {
    const index = parseInt(action[2], 10);
    popoverIndex = popoverIndex !== index ? index : -1;
  }
  else if (!aEl.target && aEl.getAttribute('href').indexOf('/') !== 0) {
    aEl.target = '_blank';
  }
}

function renderEmbed(el, embed) {
  const parentNode = embed.nodes[0] && embed.nodes[0].parentNode;
  if (parentNode && parentNode.classList) {
    const method = parentNode.classList.contains('embed') ? 'add' : 'remove';
    parentNode.classList[method]('hidden');
  }

  embed.nodes.forEach(node => el.appendChild(node));
}

function setConversationFromRoute(connection_id, conversation_id) {
  if (conversation.connection_id === connection_id && conversation.conversation_id === conversation_id) return;
  user.setActiveConversation({connection_id, conversation_id}); // Triggers setConversationFromUser()
}

function setConversationFromUser(user) {
  if (user.activeConversation === conversation) return;
  if (unsubscribe.conversation) unsubscribe.conversation();
  if (unsubscribe.unread) unsubscribe.unread();

  popoverMessage = null;
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
    <a href="#settings" class="btn-hallow can-toggle" class:is-active="{$activeMenu === 'settings'}" on:click="{activeMenu.toggle}">
      <Icon name="users-cog"/><Icon name="times"/>
    </a>
  {/if}
</ChatHeader>

{#if $activeMenu === 'settings'}
  {#if conversation_id}
    <ConversationSettings conversation="{conversation}" transition="{{duration: 250, x: $viewport.isSingleColumn ? $viewport.width : 0}}"/>
  {:else}
    <ConnectionSettings conversation="{conversation}" transition="{{duration: 250, x: $viewport.isSingleColumn ? $viewport.width : 0}}"/>
  {/if}
{/if}

<InfinityScroll class="main is-above-chat-input" on:scrolled="{e => onInfinityScrolled(e, {conversation})}" on:visibility="{e => onInfinityVisibility(e, {conversation, timestampFromUrl})}">
  {#if $messages.length < 10 && !$conversation.is('not_found')}
    <ChatWelcome conversation="{$conversation}"/>
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

    {#if i && i === $messages.length - $conversation.unread}
      <div class="message__status-line for-last-read"><span><Icon name="comments"/> {$l('New messages')}</span></div>
    {/if}

    <div class="{message.className}" class:is-not-present="{!$participants.get(message.from)}" class:is-expanded="{!!message.expanded}" data-index="{message.index}" data-ts="{message.ts.toISOString()}">
      <div class="message__ts has-tooltip">
        <span>{message.ts.format('%H:%M')}</span>
        <span class="tooltip">{nbsp(message.ts.toLocaleString())}</span>
      </div>
      <Icon name="pick:{message.from}" color="{message.color}"/>
      <a href="#action:popover:{message.index}" class="message__from prevent-default" style="color:{message.color}" tabindex="-1">{message.from}</a>
      <div class="message__text">
        {#if message.details}
          <a href="#action:expand:{message.index}" class="prevent-default"><Icon name="{message.expanded ? 'caret-square-up' : 'caret-square-down'}"/></a>
        {/if}
        {@html message.html}
      </div>
      {#each message.embeds as embedPromise}
        {#await embedPromise}
          <!-- loading embed -->
        {:then embed}
          {#if !$messages.raw}
            <div class="embed {embed.className}" use:renderEmbed="{embed}"/>
          {/if}
        {/await}
      {/each}

      <!-- popover message menu -->
      {#if popoverIndex === message.index}
        <div class="popover" transition:fade="{{duration: 200}}">
          <a href="#action:popover:{message.index}" class="prevent-default"><Icon name="pick:{message.from}" color="{message.color}"/> {message.from}</a>
          <a href="#action:mention:{encodeURIComponent(message.from)}" class="on-hover prevent-default"><Icon name="quote-left"/> {$l('Mention')}</a>
          <a href="#action:join:{encodeURIComponent(message.from)}" class="on-hover prevent-default"><Icon name="comments"/> {$l('Chat')}</a>
          <a href="#action:whois:{encodeURIComponent(message.from)}" class="on-hover prevent-default"><Icon name="address-card"/> {$l('Whois')}</a>
        </div>
      {/if}
    </div>
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
      <Link href="#action:join:{conversationName}" class="btn prevent-default"><Icon name="thumbs-up"/> <span>{$l('Yes')}</span></Link>
      <Link href="/settings/conversation" class="btn is-secondary prevent-default"><Icon name="thumbs-down"/> <span>{$l('No')}</span></Link>
    </p>
  {:else if !$connection.is('unreachable') && $connection.frozen}
    <div class="message is-highlighted" on:click="{activeMenu.toggle}">
      <div class="message__text"><Icon name="exclamation-triangle"/> {@html $lmd('Disconnected. Your connection %1 can be edited in [settings](%2).', $connection.name, '/chat/' + $connection.connection_id + '#settings')}</div>
    </div>
  {:else if $conversation.frozen && $conversation.is('pending')}
    <h2>{$l('You are invited to join %1.', conversation.name)}</h2>
    <p>{$l('Do you want to join?')}</p>
    <p>
      <Link href="#action:join:{conversationName}" class="btn prevent-default"><Icon name="thumbs-up"/> <span>{$l('Yes')}</span></Link>
      <Link href="#action:close:{conversationName}" class="btn is-secondary prevent-default"><Icon name="thumbs-down"/> <span>{$l('No')}</span></Link>
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

{#if $viewport.hasRightColumn && !$conversation.is('not_found')}
  <ChatParticipants conversation="{conversation}"/>
{/if}
