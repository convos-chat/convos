<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import Icon from '../components/Icon.svelte';
import InfinityScroll from '../components/InfinityScroll.svelte';
import {conversationUrl, gotoConversation} from '../js/chatHelpers';
import {getContext, onMount} from 'svelte';
import {l, lmd} from '../store/I18N';
import {route} from '../store/Route';

export const title = 'Search';

const user = getContext('user');
const conversation = user.search;

$: classNames = ['main', messages.length && 'has-results', $conversation.is('search') && 'is-above-chat-input'].filter(i => i);
$: messages = $conversation.messages;
$: route.param('q') && search({message: route.param('q')});

onMount(() => user.search.on('send', search));

function search(msg) {
  const match = msg.message;
  conversation.update({userInput: match});
  route.go('/search?q=' + encodeURIComponent(match), {replace: true});
  return match ? conversation.load({match}) : messages.clear();
}
</script>

<ChatHeader>
  <h1>{$l(conversation.name)}</h1>
  <a href="/search" class="btn"><Icon name="search"/></a>
</ChatHeader>

<InfinityScroll class="{classNames.join(' ')}" on:rendered="{e => e.detail.scrollTo(-1)}">

  <!-- welcome messages / status -->
  {#if $messages.length == 0 && !conversation.is('loading')}
    {#if $route.param('q')}
      <p><Icon name="info-circle"/> {$l('No search results for "%1".', $route.param('q'))}</p>
    {:else}
      <p><Icon name="info-circle"/> {@html $lmd('You can enter a channel name like #cool_beans to narrow down the search, or enter @some_nick to filter messages sent by a given user.')}</p>
    {/if}
  {/if}

  <!-- search results -->
  {#each $messages.render() as message, i}
    {#if !i || message.dayChanged}
      <div class="message__status-line for-day-changed"><span><Icon name="calendar-alt"/> <i>{message.ts.getHumanDate()}</i></span></div>
    {/if}

    <div class="{message.className}" on:click="{gotoConversation}">
      <Icon name="pick:{message.from}" color="{message.color}"/>
      <div class="message__ts has-tooltip" data-content="{message.ts.format('%H:%M')}"><div>{message.ts.toLocaleString()}</div></div>
      <a href="{conversationUrl(message)}" class="message__from" style="color:{message.color}">{$l('%1 in %2', message.from, message.conversation_id)}</a>
      <div class="message__text">{@html message.markdown}</div>
    </div>
  {/each}

  <!-- status -->
  {#if $conversation.is('loading')}
    <div class="message__status-line for-loading"><span><Icon name="spinner" animation="spin"/> <i>{$l('Loading...')}</i></span></div>
  {/if}
</InfinityScroll>

{#if conversation.is('search')}
  <ChatInput conversation="{conversation}"/>
{/if}
