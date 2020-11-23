<script>
import ChatMessage from '../components/ChatMessage.svelte';
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import Icon from '../components/Icon.svelte';
import InfinityScroll from '../components/InfinityScroll.svelte';
import {getContext, onDestroy, onMount} from 'svelte';
import {l, lmd} from '../js/i18n';
import {renderMessages} from '../js/renderMessages';
import {route} from '../store/Route';

const user = getContext('user');

let chatInputValue = '';
let conversation = $route.path.indexOf('search') == -1 ? user.notifications : user.search;

$: messages = renderMessages({conversation: $conversation});
$: classNames = ['main', messages.length && 'has-results', $conversation.is('search') && 'is-above-chat-input'].filter(i => i);
$: setConversationFromRoute($route);

onMount(() => user.search.on('send', search));
onDestroy(() => conversation.markAsRead());

function conversationUrl(message) {
  const url = ['', 'chat', message.connection_id, message.conversation_id].map(encodeURIComponent).join('/');
  return route.urlFor(url + '#' + message.ts.toISOString());
}

function gotoConversation(e) {
  if (e.target.closest('a')) return;
  e.preventDefault();
  route.go(e.target.closest('.message').querySelector('a').href);
}

function search(msg) {
  const match = msg.message;
  chatInputValue = match;
  route.go('/search?q=' + encodeURIComponent(match), {replace: true});
  return match ? conversation.load({match}) : conversation.update({messages: []});
}

function setConversationFromRoute(route) {
  const d = route.path.indexOf('search') == -1 ? user.notifications : user.search;
  if (d != conversation) conversation = d.update({conversation_id: true});
  return conversation.is('search') ? search({message: route.param('q')}) : conversation.load();
}
</script>

<ChatHeader>
  <h1><a href="#activeMenu:nav" tabindex="-1"><span>{l(conversation.name)}</span></a></h1>
  {#if $conversation.is('search')}
    <a href="/search" class="btn"><Icon name="search"/></a>
  {:else}
    <a href="/settings/account" class="btn"><Icon name="bell"/></a>
  {/if}
</ChatHeader>

<InfinityScroll class="{classNames.join(' ')}" on:rendered="{e => e.detail.scrollTo(-1)}">

  <!-- welcome messages / status -->
  {#if messages.length == 0 && !conversation.is('loading')}
    {#if conversation.is('notifications')}
      <h2>{l('No notifications.')}</h2>
    {:else if $route.param('q')}
      <ChatMessage>{l('No search results for "%1".', $route.param('q'))}</ChatMessage>
    {:else if conversation.is('search')}
      <ChatMessage>
        {@html lmd('Search for messages sent by you or others the last %1 days by writing a message in the input field below.', 90)}
        {@html lmd('You can enter a channel name, or use `"conversation:#channel"` to narrow down the search.')}
        {@html lmd('It is also possible to use `"from:some_nick"` to filter out messages from a given user.')}
      </ChatMessage>
    {/if}
  {/if}

  <!-- notifications or search results -->
  {#each messages as message, i}
    {#if !i || message.dayChanged}
      <div class="message__status-line for-day-changed"><span><Icon name="calendar-alt"/> <i>{message.ts.getHumanDate()}</i></span></div>
    {/if}

    <div class="{message.className}" on:click="{gotoConversation}">
      <Icon name="pick:{message.fromId}" color="{message.color}"/>
      <div class="message__ts has-tooltip" data-content="{message.ts.format('%H:%M')}"><div>{message.ts.toLocaleString()}</div></div>
      <a href="{conversationUrl(message)}" class="message__from" style="color:{message.color}">{l('%1 in %2', message.from, message.conversation_id)}</a>
      <div class="message__text">{@html message.markdown}</div>
    </div>
  {/each}

  <!-- status -->
  {#if $conversation.is('loading')}
    <div class="message__status-line for-loading"><span><Icon name="spinner" animation="spin"/> <i>{l('Loading...')}</i></span></div>
  {/if}
</InfinityScroll>

{#if conversation.is('search')}
  <ChatInput conversation="{conversation}" bind:value="{chatInputValue}"/>
{/if}
