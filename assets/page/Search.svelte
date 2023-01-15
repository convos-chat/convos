<script>
import ChatHeader from '../components/ChatHeader.svelte';
import ChatInput from '../components/ChatInput.svelte';
import Icon from '../components/Icon.svelte';
import InfinityScroll from '../components/InfinityScroll.svelte';
import Link from '../components/Link.svelte';
import {conversationUrl, gotoConversation} from '../js/chatHelpers';
import {getContext, onMount} from 'svelte';
import {getUserInputStore} from '../store/localstorage';
import {l, lmd} from '../store/I18N';
import {nbsp} from '../js/util';
import {route} from '../store/Route';

export const title = 'Search';

const user = getContext('user');
const conversation = user.search;

$: messages = $conversation.messages;
$: classNames = ['main', messages.length && 'has-results', $conversation.is('search') && 'is-above-chat-input'].filter(i => i);
$: hasSearch = $route.param('q') || $messages.length;
$: userInput = getUserInputStore(conversation.id);

onMount(() => {
  user.search.on('send', search);
  if (route.param('q')) search({message: route.param('q')});
});

function maybeClear(e) {
  if (hasSearch) return $messages.clear();
  e.preventDefault();
  document.querySelector('.is-primary-input').focus();
}

function search(msg) {
  const match = msg.message;
  $userInput = match;
  route.go('/search?q=' + encodeURIComponent(match), {replace: true});
  return match ? conversation.load({match}) : messages.clear();
}
</script>

<ChatHeader>
  <h1>{$l(conversation.name)}</h1>
  <Link href="/search" class="btn-hallow can-toggle {hasSearch ? 'has-tooltip is-active' : ''}" on:click="{maybeClear}">
    <Icon name="search"/><Icon name="times"/>
    <span class="tooltip is-left">{$l('Clear')}</span>
  </Link>
</ChatHeader>

<InfinityScroll class="{classNames.join(' ')}" on:rendered="{e => e.detail.scrollTo(-1)}">

  <!-- welcome messages / status -->
  {#if $messages.length === 0 && !conversation.is('loading')}
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
      <div class="message__ts has-tooltip">
        <span>{message.ts.format('%H:%M')}</span>
        <span class="tooltip">{nbsp(message.ts.toLocaleString())}</span>
      </div>
      <a href="{conversationUrl(message)}" class="message__from" style="color:{message.color}">{$l('%1 in %2', message.from, message.conversation_id)}</a>
      <div class="message__text">{@html message.html}</div>
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
